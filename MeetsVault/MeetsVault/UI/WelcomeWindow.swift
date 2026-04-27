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

private let brandColor = Color(red: 0xFB / 255.0, green: 0x74 / 255.0, blue: 0x59 / 255.0)

private struct WelcomeView: View {
    let onFinish: () -> Void

    @State private var step = 0
    @State private var termsAccepted = Settings.shared.hasAcceptedTerms
    @State private var selectedModel = Settings.shared.selectedModelName
    @State private var meetingsDir = Settings.shared.meetingsDirectory
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
        case 1: termsStep
        case 2: modelPickerStep
        case 3: folderPickerStep
        case 4: permissionsStep
        case 5: downloadStep
        default: doneStep
        }
    }

    private var termsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terms & Conditions")
                .font(.title2.bold())
            Text("Please read and accept before continuing. You are responsible for ensuring your use of MeetsVault complies with the law in your jurisdiction.")
                .foregroundColor(.secondary)
                .font(.callout)

            ScrollView {
                Text(Terms.text)
                    .font(.system(size: 11))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: termsAccepted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(termsAccepted ? brandColor : .secondary)
                Text("I have read and agree to the Terms & Conditions, and accept full responsibility for lawful use of MeetsVault.")
                    .font(.callout)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { termsAccepted.toggle() }
        }
        .padding(24)
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(brandColor)
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
            Text("Transcription runs entirely on your Mac — no audio is ever sent to a server. The model is a local AI that downloads once and stays on your device.")
                .foregroundColor(.secondary)
            Divider()
            ForEach(ModelManager.allModels, id: \.name) { model in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(model.name)
                                .fontWeight(model.name == "small" ? .semibold : .regular)
                            if model.name == "small" {
                                Text("recommended")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(brandColor.opacity(0.15))
                                    .foregroundColor(brandColor)
                                    .cornerRadius(4)
                            }
                        }
                        Text(modelDescription(model.name))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if selectedModel == model.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(brandColor)
                        }
                        Text(model.displaySize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedModel = model.name }
                .padding(.vertical, 4)
            }
        }
        .padding(32)
    }

    private var folderPickerStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Where to Save Recordings")
                .font(.title2.bold())
            Text("Transcripts and audio files will be saved here. You can change this later from the menu bar.")
                .foregroundColor(.secondary)
            Divider()
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .foregroundColor(brandColor)
                Text(displayPath(meetingsDir))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)
                Spacer()
                Button("Choose…") { pickFolder() }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            if meetingsDir == Settings.defaultMeetingsDirectory {
                Text("Default location: ~/Meetings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(32)
    }

    private func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"
        panel.message = "Choose where MeetsVault saves transcripts and audio."
        panel.directoryURL = meetingsDir
        if panel.runModal() == .OK, let url = panel.url {
            meetingsDir = url
        }
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
                .tint(brandColor)
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
                    .foregroundColor(brandColor)
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
                .foregroundColor(brandColor)
            Text("You're all set!")
                .font(.title.bold())
            Text("MeetsVault lives in your menu bar. Click the waveform icon to start or stop recordings. You can also trigger it via URL scheme:\nmeetsvault://start?title=Meeting+Name")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }

    private func modelDescription(_ name: String) -> String {
        switch name {
        case "tiny":  return "Fast transcription. Good for short meetings or limited storage."
        case "base":  return "Casual use where speed matters more than accuracy."
        case "small": return "Best for most users. Solid accuracy at reasonable speed."
        case "medium": return "Better with accents, technical terms, or multiple languages."
        case "large-v3": return "Highest accuracy. Slow and needs ~3 GB of disk space."
        default: return ""
        }
    }

    // MARK: Navigation

    @ViewBuilder
    private var navigationButtons: some View {
        switch step {
        case 0, 1, 2, 3, 4:
            Button(step == 4 ? "Download Model" : "Next") {
                advanceStep()
            }
            .buttonStyle(.borderedProminent)
            .tint(brandColor)
            .keyboardShortcut(.defaultAction)
            .disabled(step == 1 && !termsAccepted)

        case 5:
            if downloadError != nil {
                Button("Retry") {
                    downloadError = nil
                    startDownload()
                }
                .buttonStyle(.borderedProminent)
                .tint(brandColor)
            } else if !isDownloading {
                Button("Next") { step += 1 }
                    .buttonStyle(.borderedProminent)
                    .tint(brandColor)
                    .keyboardShortcut(.defaultAction)
            } else {
                // downloading — button disabled
                Button("Next") {}
                    .buttonStyle(.borderedProminent)
                    .tint(brandColor)
                    .disabled(true)
            }

        default:
            Button("Finish") {
                Settings.shared.hasCompletedOnboarding = true
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .tint(brandColor)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func advanceStep() {
        switch step {
        case 1:
            Settings.shared.hasAcceptedTerms = true
        case 2:
            Settings.shared.selectedModelName = selectedModel
        case 3:
            Settings.shared.meetingsDirectory = meetingsDir
            try? FileManager.default.createDirectory(at: meetingsDir, withIntermediateDirectories: true)
        default:
            break
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
