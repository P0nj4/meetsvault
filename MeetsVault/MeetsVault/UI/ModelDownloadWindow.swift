import AppKit
import SwiftUI

// MARK: - Window controller

final class ModelDownloadWindowController: NSWindowController, NSWindowDelegate {
    private var committed = false
    private var onCommitCallback: ((String) -> Void)?
    private var onCancelCallback: (() -> Void)?
    private var viewModel: ModelDownloadModel?

    convenience init(
        preselected: String,
        onCommit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onDownloadStateChange: @escaping (Bool) -> Void
    ) {
        let vm = ModelDownloadModel(preselected: preselected, onDownloadStateChange: onDownloadStateChange)
        let view = ModelDownloadView(viewModel: vm)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 520, height: 480))
        window.styleMask = [.titled, .closable]
        window.title = "Change Transcription Model"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
        self.viewModel = vm
        self.onCommitCallback = onCommit
        self.onCancelCallback = onCancel
        window.delegate = self

        vm.onCommitRequest = { [weak self] name in
            self?.committed = true
            onCommit(name)
            self?.closeWindow()
        }
    }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
    }

    // MARK: NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let vm = viewModel, case .downloading = vm.phase {
            vm.cancelActiveDownload()
        }
        if !committed {
            onCancelCallback?()
        }
        return true
    }
}

// MARK: - View model

final class ModelDownloadModel: ObservableObject {
    enum Phase {
        case picking(selection: String)
        case confirming(model: String)
        case downloading(model: String, progress: Double)
        case done(model: String)
        case failed(model: String, error: String)
    }

    @Published var phase: Phase
    var downloadTask: Task<Void, Error>?
    var onCommitRequest: ((String) -> Void)?

    private let onDownloadStateChange: (Bool) -> Void

    init(preselected: String, onDownloadStateChange: @escaping (Bool) -> Void) {
        self.phase = .picking(selection: preselected)
        self.onDownloadStateChange = onDownloadStateChange
    }

    @MainActor
    func selectOrDownload(_ name: String) {
        switch phase {
        case .picking, .confirming:
            if ModelManager.shared.isDownloaded(name) {
                phase = .done(model: name)
            } else {
                phase = .confirming(model: name)
            }
        default:
            break
        }
    }

    @MainActor
    func confirmDownload() {
        guard case .confirming(let name) = phase else { return }
        startDownload(name)
    }

    @MainActor
    func startDownload(_ name: String) {
        onDownloadStateChange(true)
        phase = .downloading(model: name, progress: 0)
        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await ModelManager.shared.download(name) { [weak self] p in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if case .downloading = self.phase {
                            self.phase = .downloading(model: name, progress: p)
                        }
                    }
                }
                await MainActor.run { [weak self] in
                    self?.phase = .done(model: name)
                }
            } catch is CancellationError {
                // window is closing — no UI update needed
            } catch {
                let msg = error.localizedDescription
                await MainActor.run { [weak self] in
                    self?.phase = .failed(model: name, error: msg)
                }
            }
            await MainActor.run { [weak self] in
                self?.onDownloadStateChange(false)
                self?.downloadTask = nil
            }
        }
    }

    func cancelActiveDownload() {
        downloadTask?.cancel()
        downloadTask = nil
    }

    func commit(_ name: String) {
        onCommitRequest?(name)
    }
}

// MARK: - SwiftUI view

private let brandColor = Color(red: 0xFB / 255.0, green: 0x74 / 255.0, blue: 0x59 / 255.0)

private func modelDescription(_ name: String) -> String {
    switch name {
    case "tiny":     return "Fast transcription. Good for short meetings or limited storage."
    case "base":     return "Casual use where speed matters more than accuracy."
    case "small":    return "Best for most users. Solid accuracy at reasonable speed."
    case "medium":   return "Better with accents, technical terms, or multiple languages."
    case "large-v3": return "Highest accuracy. Slow and needs ~3 GB of disk space."
    default:         return ""
    }
}

private struct ModelDownloadView: View {
    @ObservedObject var viewModel: ModelDownloadModel

    var body: some View {
        Group {
            if case .done(let name) = viewModel.phase {
                doneScreen(model: name)
            } else {
                listLayout
            }
        }
        .frame(width: 520, height: 480)
    }

    // MARK: Done screen

    private func doneScreen(model: String) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                Text("Model changed!")
                    .font(.title.bold())
                Text("\(model) is now your transcription model.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(40)
            Spacer()
            Divider()
            HStack {
                Spacer()
                Button("Done") { viewModel.commit(model) }
                    .buttonStyle(.borderedProminent)
                    .tint(brandColor)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
    }

    // MARK: List layout

    private var listLayout: some View {
        VStack(spacing: 0) {
            modelList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            bottomArea
                .padding(20)
                .frame(minHeight: 80)
        }
    }

    private var modelList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose a Transcription Model")
                    .font(.title2.bold())
                    .padding(.bottom, 8)

                ForEach(ModelManager.allModels, id: \.name) { model in
                    modelRow(model)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            switch viewModel.phase {
                            case .picking, .confirming:
                                Task { @MainActor in viewModel.selectOrDownload(model.name) }
                            default:
                                break
                            }
                        }
                        .opacity(rowOpacity(for: model.name))
                }
            }
            .padding(32)
        }
    }

    private func rowOpacity(for name: String) -> Double {
        switch viewModel.phase {
        case .picking, .confirming:
            return 1.0
        case .downloading, .failed:
            return isCurrentlySelected(name) ? 1.0 : 0.4
        default:
            return 1.0
        }
    }

    private func isCurrentlySelected(_ name: String) -> Bool {
        switch viewModel.phase {
        case .picking(let sel):    return sel == name
        case .confirming(let m):   return m == name
        case .downloading(let m, _): return m == name
        case .failed(let m, _):    return m == name
        case .done(let m):         return m == name
        }
    }

    private func modelRow(_ model: (name: String, displaySize: String)) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .fontWeight(model.name == "small" ? .semibold : .regular)
                    if ModelManager.shared.isDownloaded(model.name) {
                        Text("Downloaded")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }
                Text(modelDescription(model.name))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                selectionIndicator(for: model.name)
                Text(model.displaySize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func selectionIndicator(for name: String) -> some View {
        if isCurrentlySelected(name) {
            switch viewModel.phase {
            case .picking, .confirming:
                Image(systemName: "checkmark.circle.fill").foregroundColor(brandColor)
            case .downloading:
                Image(systemName: "arrow.down.circle.fill").foregroundColor(brandColor)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            }
        } else {
            Color.clear.frame(width: 16, height: 16)
        }
    }

    // MARK: Bottom area

    @ViewBuilder
    private var bottomArea: some View {
        switch viewModel.phase {
        case .picking:
            EmptyView()

        case .confirming(let name):
            HStack {
                Text("Tap Change to switch to \(name).")
                    .foregroundColor(.secondary)
                Spacer()
                Button("Change") {
                    Task { @MainActor in viewModel.confirmDownload() }
                }
                .buttonStyle(.borderedProminent)
                .tint(brandColor)
                .keyboardShortcut(.defaultAction)
            }

        case .downloading(let name, let progress):
            VStack(spacing: 10) {
                HStack {
                    Text("Downloading \(name)…")
                        .font(.callout)
                    Spacer()
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                ProgressView(value: progress > 0 ? progress : nil)
                    .progressViewStyle(.linear)
                HStack {
                    Spacer()
                    Button("Change") { }
                        .buttonStyle(.borderedProminent)
                        .tint(brandColor)
                        .disabled(true)
                }
            }

        case .failed(let name, let error):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer()
                Button("Retry") {
                    Task { @MainActor in viewModel.startDownload(name) }
                }
                .buttonStyle(.borderedProminent)
                .tint(brandColor)
            }

        case .done:
            EmptyView()
        }
    }
}
