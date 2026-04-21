import Foundation

enum RecordingState {
    case idle
    case recording
    case transcribing
}

protocol AudioRecorderDelegate: AnyObject {
    func recorder(_ recorder: AudioRecorder, didChangeState state: RecordingState)
    func recorder(_ recorder: AudioRecorder, didFinishTranscript url: URL, title: String)
    func recorder(_ recorder: AudioRecorder, didFail error: Error)
}

final class AudioRecorder {
    weak var delegate: AudioRecorderDelegate?
    private(set) var state: RecordingState = .idle {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.recorder(self, didChangeState: self.state)
            }
        }
    }

    private var sessionDir: URL?
    private var sessionTitle: String?
    private var sessionStartDate: Date?
    private let micCapture = MicrophoneCapture()
    private let systemCapture = SystemAudioCapture()

    func start(title: String?) async throws {
        guard state == .idle else {
            NSLog("[MeetsVault] Already recording — ignoring start")
            return
        }

        // Check permissions
        if !PermissionsChecker.microphoneGranted {
            let granted = await PermissionsChecker.requestMicrophone()
            guard granted else { throw RecorderError.microphonePermissionDenied }
        }
        if !PermissionsChecker.screenRecordingGranted {
            PermissionsChecker.requestScreenRecording()
            throw RecorderError.screenCapturePermissionDenied
        }

        // Create session directory
        let uuid = UUID().uuidString
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MeetsVault/recordings/\(uuid)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        sessionDir = dir
        sessionTitle = title
        sessionStartDate = Date()

        let micURL = dir.appendingPathComponent("mic.wav")
        let systemURL = dir.appendingPathComponent("system.wav")

        try micCapture.start(to: micURL)
        try await systemCapture.start(to: systemURL)

        state = .recording
        NSLog("[MeetsVault] Recording started — session: %@", uuid)
    }

    func stop() async {
        guard state == .recording, let dir = sessionDir else {
            NSLog("[MeetsVault] Not recording — ignoring stop")
            return
        }

        state = .transcribing
        let endDate = Date()

        micCapture.stop()
        await systemCapture.stop()

        let micURL = dir.appendingPathComponent("mic.wav")
        let systemURL = dir.appendingPathComponent("system.wav")
        let combinedURL = dir.appendingPathComponent("combined.wav")

        do {
            NSLog("[MeetsVault] Mixing audio...")
            try AudioMixer.mix(mic: micURL, system: systemURL, output: combinedURL)
            NSLog("[MeetsVault] Mix complete: %@", combinedURL.path)

            let modelName = Settings.shared.selectedModelName
            let language = Settings.shared.transcriptionLanguage
            NSLog("[MeetsVault] Transcribing with model: %@, language: %@", modelName, language)

            let engine = WhisperKitEngine()
            try await engine.prepare(modelName: modelName, progress: { p in
                NSLog("[MeetsVault] Model load: %.0f%%", p * 100)
            })
            let segments = try await engine.transcribe(
                audioURL: combinedURL,
                language: language.isEmpty ? nil : language
            )
            for seg in segments {
                NSLog("[MeetsVault] [%@] %@", Self.formatTime(seg.startSeconds), seg.text)
            }
            NSLog("[MeetsVault] Transcription complete — %d segments", segments.count)

            // Phase 5 will write the markdown file and notify.
        } catch {
            NSLog("[MeetsVault] Stop failed: %@", error.localizedDescription)
            delegate?.recorder(self, didFail: error)
        }

        sessionDir = nil
        sessionTitle = nil
        sessionStartDate = nil
        state = .idle
    }

    private static func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

enum RecorderError: LocalizedError {
    case microphonePermissionDenied
    case screenCapturePermissionDenied

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access denied. Open System Settings → Privacy & Security → Microphone."
        case .screenCapturePermissionDenied:
            return "Screen Recording access denied. Open System Settings → Privacy & Security → Screen Recording."
        }
    }
}
