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
    private(set) var state: RecordingState = .idle

    // Implemented in Phase 2
    func start(title: String?) async throws {
        NSLog("[MeetsVault] AudioRecorder.start — not yet implemented")
    }

    func stop() async {
        NSLog("[MeetsVault] AudioRecorder.stop — not yet implemented")
    }
}
