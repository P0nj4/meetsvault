import Foundation
import WhisperKit

final class WhisperKitEngine: TranscriptionEngine {
    private var pipeline: WhisperKit?

    private static let modelsDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MeetsVault/models")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func prepare(modelName: String, progress: @escaping (Double) -> Void) async throws {
        let variant = "openai_whisper-\(modelName)"
        progress(0.0)

        // Download with progress reporting (no-op if already cached)
        let modelFolder = try await WhisperKit.download(
            variant: variant,
            downloadBase: Self.modelsDir,
            progressCallback: { p in
                progress(p.fractionCompleted * 0.8)  // download = 0→80%
            }
        )

        progress(0.85)
        pipeline = try await WhisperKit(modelFolder: modelFolder.path())
        progress(1.0)
    }

    func transcribe(audioURL: URL, language: String?, speaker: Speaker) async throws -> [TranscriptSegment] {
        guard let pipeline else { throw EngineError.notPrepared }
        var options = DecodingOptions()
        if let lang = language {
            options.language = lang
        }
        let results = try await pipeline.transcribe(audioPath: audioURL.path, decodeOptions: options)
        return (results ?? []).flatMap { result in
            result.segments.compactMap { seg -> TranscriptSegment? in
                let cleaned = TranscriptCleaner.stripTokens(seg.text)
                guard !cleaned.isEmpty else { return nil }
                return TranscriptSegment(
                    startSeconds: Double(seg.start),
                    endSeconds: Double(seg.end),
                    text: cleaned,
                    speaker: speaker
                )
            }
        }
    }
}

enum EngineError: LocalizedError {
    case notPrepared
    var errorDescription: String? { "Transcription engine not loaded. Call prepare() first." }
}
