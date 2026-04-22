import AppKit
import os.log

private let log = OSLog(subsystem: "com.germanpereyra.meetsvault", category: "MenuBar")

final class MenuBarController: AudioRecorderDelegate {
    private let statusItem: NSStatusItem
    let recorder = AudioRecorder()

    private var iconState: MenuBarIconState = .idle {
        didSet { updateIcon() }
    }
    private var recordingTimer: Timer?
    private var recordingReminderTimer: Timer?
    private var transcribingTimer: Timer?
    private var transcribingFrame = 0
    private let transcribingValues: [Double] = [1.0, 0.6, 0.2, 0.6]
    private var recordingStart: Date?
    private var aboutWindowController: AboutWindowController?
    private var modelDownloadWindowController: ModelDownloadWindowController?
    private var isDownloadingModel = false

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        recorder.delegate = self
        updateIcon()
        buildMenu()
    }

    deinit {
        recordingTimer?.invalidate()
        recordingReminderTimer?.invalidate()
        transcribingTimer?.invalidate()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Icon

    private func updateIcon() {
        if iconState == .transcribing {
            let value = transcribingValues[transcribingFrame % transcribingValues.count]
            let img = NSImage(systemSymbolName: "waveform", variableValue: value, accessibilityDescription: nil)!
            let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let configured = img.withSymbolConfiguration(cfg)!
            configured.isTemplate = true
            statusItem.button?.image = configured
        } else {
            statusItem.button?.image = iconState.image
        }
        statusItem.button?.toolTip = "MeetsVault"
    }

    // MARK: - Menu

    func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

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
            startItem.isEnabled = !isDownloadingModel
            menu.addItem(startItem)
        }

        menu.addItem(.separator())

        let openFolderItem = NSMenuItem(title: "Open Meetings Folder", action: #selector(openMeetingsFolder), keyEquivalent: "")
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        let recentItem = NSMenuItem(title: "Recent Transcripts", action: nil, keyEquivalent: "")
        recentItem.submenu = makeRecentTranscriptsMenu()
        menu.addItem(recentItem)

        menu.addItem(.separator())

        menu.addItem(makeLanguageSubmenu())
        menu.addItem(makeModelSubmenu())

        let reTranscribeItem = NSMenuItem(title: "Re-transcribe audio…", action: #selector(reTranscribeAudio), keyEquivalent: "")
        reTranscribeItem.target = self
        reTranscribeItem.isEnabled = recorder.state == .idle && !isDownloadingModel
        menu.addItem(reTranscribeItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About MeetsVault", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit MeetsVault", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeRecentTranscriptsMenu() -> NSMenu {
        let sub = NSMenu()
        let meetingsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Meetings")
        let recents = (try? FileManager.default.contentsOfDirectory(
            at: meetingsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ))?.filter { $0.pathExtension == "md" }
            .sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return d1 > d2
            }
            .prefix(5) ?? []

        if recents.isEmpty {
            let empty = NSMenuItem(title: "No recent transcripts", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            sub.addItem(empty)
        } else {
            for url in recents {
                let mi = NSMenuItem(title: url.deletingPathExtension().lastPathComponent, action: #selector(openTranscript(_:)), keyEquivalent: "")
                mi.target = self
                mi.representedObject = url
                sub.addItem(mi)
            }
        }
        return sub
    }

    @objc private func openTranscript(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    private func makeLanguageSubmenu() -> NSMenuItem {
        let current = Settings.shared.transcriptionLanguage
        let currentName = LanguageCode.top.first { $0.code == current }?.displayName ?? current.uppercased()
        let item = NSMenuItem(title: "Language: \(currentName)", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for lang in LanguageCode.top {
            let mi = NSMenuItem(title: lang.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = lang.code
            if lang.code == current { mi.state = .on }
            sub.addItem(mi)
        }
        sub.addItem(.separator())
        let moreItem = NSMenuItem(title: "More Languages…", action: #selector(showMoreLanguages), keyEquivalent: "")
        moreItem.target = self
        sub.addItem(moreItem)
        item.submenu = sub
        return item
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        Settings.shared.transcriptionLanguage = code
        buildMenu()
    }

    @objc private func showMoreLanguages() {
        // Show all Whisper languages in a simple picker (uses NSMenu on a status item re-open).
        // For now, build a second-level submenu is not feasible from here; show an alert with instructions.
        let alert = NSAlert()
        alert.messageText = "More Languages"
        alert.informativeText = "Set a language code in:\ndefaults write com.germanpereyra.meetsvault transcriptionLanguage <code>\n\nExamples: ar, cs, nl, fi, pl, sv, tr…"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func makeModelSubmenu() -> NSMenuItem {
        let current = Settings.shared.selectedModelName
        let modelBlocked = recorder.state != .idle || isDownloadingModel
        let item = NSMenuItem(title: "Model: \(current)", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.autoenablesItems = false
        let switchItem = NSMenuItem(title: "Switch Model", action: #selector(openModelDownloadWindow), keyEquivalent: "")
        switchItem.target = self
        switchItem.isEnabled = !modelBlocked
        sub.addItem(switchItem)
        item.submenu = sub
        return item
    }

    @objc private func openModelDownloadWindow() {
        guard recorder.state == .idle, !isDownloadingModel else { return }
        guard modelDownloadWindowController == nil else {
            modelDownloadWindowController?.show()
            return
        }
        let wc = ModelDownloadWindowController(
            preselected: Settings.shared.selectedModelName,
            onCommit: { [weak self] committed in
                Settings.shared.selectedModelName = committed
                self?.modelDownloadWindowController = nil
                self?.buildMenu()
            },
            onCancel: { [weak self] in
                self?.modelDownloadWindowController = nil
                self?.buildMenu()
            },
            onDownloadStateChange: { [weak self] downloading in
                self?.isDownloadingModel = downloading
                self?.buildMenu()
            }
        )
        modelDownloadWindowController = wc
        wc.show()
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
        let url = Settings.shared.meetingsDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    @objc private func reTranscribeAudio() {
        let panel = NSOpenPanel()
        panel.title = "Select a WAV file to re-transcribe"
        panel.allowedContentTypes = [.wav]
        panel.directoryURL = Settings.shared.meetingsDirectory
        guard panel.runModal() == .OK, let wavURL = panel.url else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let modelName = Settings.shared.selectedModelName
                let language = Settings.shared.transcriptionLanguage
                let engine = WhisperKitEngine()
                try await engine.prepare(modelName: modelName) { _ in }
                let segments = try await engine.transcribe(audioURL: wavURL, language: language.isEmpty ? nil : language, speaker: .you)

                let fmt = DateFormatter()
                fmt.dateFormat = "yyyyMMdd-HHmmss"
                let suffix = fmt.string(from: Date())
                let baseName = wavURL.deletingPathExtension().lastPathComponent + "-retranscribed-\(suffix)"
                let mdURL = FilenameBuilder.uniqueMarkdownURL(
                    base: baseName,
                    in: wavURL.deletingLastPathComponent()
                )
                let markdown = buildReTranscribeMarkdown(segments: segments, audioURL: wavURL, modelName: modelName, language: language)
                try markdown.write(to: mdURL, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(mdURL)
                os_log("Re-transcribe saved: %{public}@", log: log, type: .info, mdURL.path)
            } catch {
                os_log("Re-transcribe failed: %{public}@", log: log, type: .error, error.localizedDescription)
                await MainActor.run { self.showError("Re-transcription failed: \(error.localizedDescription)") }
            }
        }
    }

    private func buildReTranscribeMarkdown(segments: [TranscriptSegment], audioURL: URL, modelName: String, language: String) -> String {
        var md = """
        ---
        audio_file: \(audioURL.lastPathComponent)
        retranscribed_at: \(ISO8601DateFormatter().string(from: Date()))
        language: \(language)
        model: whisperkit-\(modelName)
        ---

        ## Transcript

        """
        for seg in segments {
            let s = Int(seg.startSeconds)
            let ts = String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            md += "[\(ts)] \(seg.text)\n"
        }
        return md
    }

    @objc private func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.show()
    }

    // MARK: - AudioRecorderDelegate

    func recorder(_ recorder: AudioRecorder, didChangeState state: RecordingState) {
        switch state {
        case .idle:
            recordingTimer?.invalidate()
            recordingTimer = nil
            recordingReminderTimer?.invalidate()
            recordingReminderTimer = nil
            transcribingTimer?.invalidate()
            transcribingTimer = nil
            transcribingFrame = 0
            recordingStart = nil
            iconState = .idle
        case .recording:
            recordingStart = Date()
            iconState = .recording
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.buildMenu()
            }
            recordingReminderTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
                NotificationManager.shared.postRecordingReminder()
            }
        case .transcribing:
            recordingTimer?.invalidate()
            recordingTimer = nil
            recordingReminderTimer?.invalidate()
            recordingReminderTimer = nil
            iconState = .transcribing
            transcribingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.transcribingFrame = (self.transcribingFrame + 1) % self.transcribingValues.count
                self.updateIcon()
            }
        }
        buildMenu()
    }

    func recorder(_ recorder: AudioRecorder, didFinishTranscript url: URL, title: String) {
        buildMenu()
    }

    func recorder(_ recorder: AudioRecorder, didFail error: Error) {
        os_log("Recorder error: %{public}@", log: log, type: .error, error.localizedDescription)
        NotificationManager.shared.postInfo("MeetsVault error", body: error.localizedDescription)
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        os_log("Error: %{public}@", log: log, type: .error, message)
        NotificationManager.shared.postInfo("MeetsVault error", body: message)
    }
}
