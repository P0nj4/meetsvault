import AppKit
import SwiftUI

// MARK: - Window controller

final class WelcomeWindowController: NSWindowController {
    private var onFinishCallback: (() -> Void)?

    convenience init(onFinish: @escaping () -> Void) {
        let view = WelcomeView(onFinish: onFinish)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 520, height: 440))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "Welcome to MeetsVault"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
        onFinishCallback = onFinish
    }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
    }
}

// MARK: - SwiftUI view

private struct WelcomeView: View {
    let onFinish: () -> Void

    @State private var step = 0
    @State private var selectedModel = Settings.shared.selectedModelName
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?
    @State private var micGranted = PermissionsChecker.microphoneGranted
    @State private var screenGranted = PermissionsChecker.screenRecordingGranted

    var body: some View {
        VStack(spacing: 0) {
            stepView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Spacer()
                navigationButtons
            }
            .padding(20)
        }
        .frame(width: 520, height: 440)
    }

    // MARK: Steps

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case 0: welcomeStep
        case 1: modelPickerStep
        case 2: permissionsStep
        case 3: downloadStep
        default: doneStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            Text("Welcome to MeetsVault")
                .font(.title.bold())
            Text("MeetsVault lives in your menu bar and records meetings locally — no cloud, no subscription, fully private. Transcription runs on your Mac using Apple Neural Engine.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }

    private var modelPickerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a Transcription Model")
                .font(.title2.bold())
            Text("The model downloads once and runs locally. Larger models are more accurate but slower.")
                .foregroundColor(.secondary)
            Divider()
            ForEach(ModelManager.allModels, id: \.name) { model in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name)
                            .fontWeight(model.name == "small" ? .semibold : .regular)
                        Text(model.displaySize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if selectedModel == model.name {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedModel = model.name }
                .padding(.vertical, 4)
            }
        }
        .padding(32)
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Permissions Required")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Captures your voice during meetings.",
                    granted: micGranted
                )
                permissionRow(
                    icon: "display",
                    title: "Screen Recording",
                    description: "Captures system audio from other participants. Your screen is never recorded.",
                    granted: screenGranted
                )
            }
            if !screenGranted {
                Text("After granting Screen Recording, you may need to quit and relaunch MeetsVault once.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if allPermissionsGranted {
                Label("All permissions granted", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            } else {
                Button("Request Permissions") {
                    requestPermissions()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .onAppear { refreshPermissions() }
    }

    private var allPermissionsGranted: Bool { micGranted && screenGranted }

    private func permissionRow(icon: String, title: String, description: String, granted: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : icon)
                .frame(width: 24)
                .foregroundColor(granted ? .green : .accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(granted ? "Access granted" : description)
                    .foregroundColor(granted ? .green : .secondary)
            }
        }
    }

    private func refreshPermissions() {
        micGranted = PermissionsChecker.microphoneGranted
        screenGranted = PermissionsChecker.screenRecordingGranted
    }

    private var downloadStep: some View {
        VStack(spacing: 20) {
            if isDownloading {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("Downloading \(selectedModel) model…")
                    .font(.title3.bold())
                ProgressView(value: downloadProgress > 0 ? downloadProgress : nil)
                    .progressViewStyle(.linear)
                    .frame(width: 300)
                Text(downloadProgress > 0 ? String(format: "%.0f%%", downloadProgress * 100) : "Starting…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let error = downloadError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text("Download failed")
                    .font(.title3.bold())
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Model ready")
                    .font(.title3.bold())
            }
        }
        .padding(40)
        .onAppear { startDownload() }
    }

    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "menubar.dock.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            Text("You're all set!")
                .font(.title.bold())
            Text("MeetsVault lives in your menu bar. Click the waveform icon to start or stop recordings. You can also trigger it via URL scheme:\nmeetsvault://start?title=Meeting+Name")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }

    // MARK: Navigation

    @ViewBuilder
    private var navigationButtons: some View {
        switch step {
        case 0, 1, 2:
            Button(step == 2 ? "Download Model" : "Next") {
                advanceStep()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)

        case 3:
            if downloadError != nil {
                Button("Retry") {
                    downloadError = nil
                    startDownload()
                }
                .buttonStyle(.borderedProminent)
            } else if !isDownloading {
                Button("Next") { step += 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Next") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
            }

        default:
            Button("Finish") {
                Settings.shared.hasCompletedOnboarding = true
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func advanceStep() {
        if step == 1 {
            Settings.shared.selectedModelName = selectedModel
        }
        step += 1
    }

    // MARK: Actions

    private func requestPermissions() {
        Task {
            _ = await PermissionsChecker.requestMicrophone()
            PermissionsChecker.requestScreenRecording()
            await MainActor.run { refreshPermissions() }
        }
    }

    private func startDownload() {
        isDownloading = true
        downloadProgress = 0
        downloadError = nil
        Task {
            do {
                try await ModelManager.shared.download(selectedModel) { p in
                    Task { @MainActor in downloadProgress = p }
                }
                await MainActor.run {
                    isDownloading = false
                    downloadProgress = 1.0
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadError = error.localizedDescription
                }
            }
        }
    }
}
