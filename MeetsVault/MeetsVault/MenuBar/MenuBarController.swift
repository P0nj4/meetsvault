import AppKit

final class MenuBarController: AudioRecorderDelegate {
    private let statusItem: NSStatusItem
    let recorder = AudioRecorder()

    private var iconState: MenuBarIconState = .idle {
        didSet { updateIcon() }
    }
    private var recordingTimer: Timer?
    private var recordingStart: Date?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        recorder.delegate = self
        updateIcon()
        buildMenu()
    }

    deinit {
        recordingTimer?.invalidate()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Icon

    private func updateIcon() {
        statusItem.button?.image = iconState.image
        statusItem.button?.toolTip = "MeetsVault"
    }

    // MARK: - Menu

    func buildMenu() {
        let menu = NSMenu()

        switch recorder.state {
        case .recording:
            let elapsedItem = NSMenuItem(title: elapsedString(), action: nil, keyEquivalent: "")
            elapsedItem.isEnabled = false
            menu.addItem(elapsedItem)
            menu.addItem(.separator())

            let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "")
            stopItem.target = self
            menu.addItem(stopItem)

        case .transcribing:
            let transcribingItem = NSMenuItem(title: "Transcribing…", action: nil, keyEquivalent: "")
            transcribingItem.isEnabled = false
            menu.addItem(transcribingItem)

        case .idle:
            let startItem = NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "")
            startItem.target = self
            menu.addItem(startItem)
        }

        menu.addItem(.separator())

        let openFolderItem = NSMenuItem(title: "Open Meetings Folder", action: #selector(openMeetingsFolder), keyEquivalent: "")
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit MeetsVault", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func elapsedString() -> String {
        let elapsed = Int(Date().timeIntervalSince(recordingStart ?? Date()))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        if h > 0 {
            return String(format: "● Recording · %d:%02d:%02d", h, m, s)
        }
        return String(format: "● Recording · %02d:%02d", m, s)
    }

    // MARK: - Actions

    @objc private func startRecording() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.recorder.start(title: nil)
            } catch {
                NSLog("[MeetsVault] Start failed: %@", error.localizedDescription)
                let message = error.localizedDescription
                await MainActor.run { self.showError(message) }
            }
        }
    }

    @objc private func stopRecording() {
        Task { [weak self] in
            await self?.recorder.stop()
        }
    }

    @objc private func openMeetingsFolder() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Meetings")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    // MARK: - AudioRecorderDelegate

    func recorder(_ recorder: AudioRecorder, didChangeState state: RecordingState) {
        switch state {
        case .idle:
            recordingTimer?.invalidate()
            recordingTimer = nil
            recordingStart = nil
            iconState = .idle
        case .recording:
            recordingStart = Date()
            iconState = .recording
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.buildMenu()
            }
        case .transcribing:
            recordingTimer?.invalidate()
            recordingTimer = nil
            iconState = .transcribing
        }
        buildMenu()
    }

    func recorder(_ recorder: AudioRecorder, didFinishTranscript url: URL, title: String) {
        // Wired in Phase 5
    }

    func recorder(_ recorder: AudioRecorder, didFail error: Error) {
        showError(error.localizedDescription)
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "MeetsVault"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
