import Foundation

protocol TranscriptionEngine {
    /// One-time setup; downloads model if needed. Reports progress 0.0…1.0.
    func prepare(modelName: String, progress: @escaping (Double) -> Void) async throws

    /// Transcribe the given .wav file. Returns ordered segments.
    func transcribe(audioURL: URL, language: String?) async throws -> [TranscriptSegment]
}
