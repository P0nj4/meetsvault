import Foundation
import os.log

private let log = OSLog(subsystem: "com.germanpereyra.meetsvault", category: "AudioRecorder")

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
    private var sessionEndDate: Date?
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
        sessionEndDate = endDate

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
            let lang = language.isEmpty ? nil : language
            let micSegments = try await engine.transcribe(audioURL: micURL, language: lang, speaker: .you)
            let systemSegments = try await engine.transcribe(audioURL: systemURL, language: lang, speaker: .others)

            let micFirst = micCapture.firstSampleTime
            let systemFirst = systemCapture.firstSampleTime
            let anchor: Date? = [micFirst, systemFirst].compactMap { $0 }.min()
            let micOffset = (micFirst != nil && anchor != nil) ? micFirst!.timeIntervalSince(anchor!) : 0
            let systemOffset = (systemFirst != nil && anchor != nil) ? systemFirst!.timeIntervalSince(anchor!) : 0
            NSLog("[MeetsVault] Stream offsets — mic: %.3fs, system: %.3fs", micOffset, systemOffset)

            let alignedMic = micSegments.map { TranscriptSegment(startSeconds: $0.startSeconds + micOffset, endSeconds: $0.endSeconds + micOffset, text: $0.text, speaker: $0.speaker) }
            let alignedSystem = systemSegments.map { TranscriptSegment(startSeconds: $0.startSeconds + systemOffset, endSeconds: $0.endSeconds + systemOffset, text: $0.text, speaker: $0.speaker) }

            let segments = TranscriptDeduplicator.dedupe(mic: alignedMic, system: alignedSystem)
            NSLog("[MeetsVault] After dedup: %d mic + %d system → %d segments",
                  alignedMic.count, alignedSystem.count, segments.count)
            for seg in segments {
                NSLog("[MeetsVault] [%@] %@", Self.formatTime(seg.startSeconds), seg.text)
            }
            NSLog("[MeetsVault] Transcription complete — %d segments", segments.count)

            let mdURL = try TranscriptWriter.write(
                title: sessionTitle,
                startedAt: sessionStartDate ?? endDate,
                endedAt: endDate,
                language: language,
                modelName: modelName,
                segments: segments,
                combinedAudioURL: combinedURL
            )
            NSLog("[MeetsVault] Transcript saved: %@", mdURL.path)

            let title = sessionTitle ?? "Untitled"
            let duration = endDate.timeIntervalSince(sessionStartDate ?? endDate)
            NotificationManager.shared.postTranscriptReady(fileURL: mdURL, title: title, duration: duration)

            let capturedDelegate = delegate
            let capturedTitle = title
            DispatchQueue.main.async {
                capturedDelegate?.recorder(self, didFinishTranscript: mdURL, title: capturedTitle)
            }

            // Clean up session folder (audio was moved to ~/Meetings)
            try? FileManager.default.removeItem(at: dir)
        } catch {
            NSLog("[MeetsVault] Stop failed: %@", error.localizedDescription)
            delegate?.recorder(self, didFail: error)
        }

        sessionDir = nil
        sessionTitle = nil
        sessionStartDate = nil
        sessionEndDate = nil
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
