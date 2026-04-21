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
        progress(0.05)
        pipeline = try await WhisperKit(
            model: variant,
            downloadBase: Self.modelsDir,
            verbose: false,
            logLevel: .none,
            prewarm: true,
            load: true,
            download: true
        )
        progress(1.0)
    }

    func transcribe(audioURL: URL, language: String?) async throws -> [TranscriptSegment] {
        guard let pipeline else { throw EngineError.notPrepared }
        var options = DecodingOptions()
        if let lang = language {
            options.language = lang
        }
        let results = try await pipeline.transcribe(audioPath: audioURL.path, decodeOptions: options)
        return (results ?? []).flatMap { result in
            result.segments.map { seg in
                TranscriptSegment(
                    startSeconds: Double(seg.start),
                    endSeconds: Double(seg.end),
                    text: seg.text.trimmingCharacters(in: .whitespaces)
                )
            }
        }
    }
}

enum EngineError: LocalizedError {
    case notPrepared
    var errorDescription: String? { "Transcription engine not loaded. Call prepare() first." }
}
