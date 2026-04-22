import Foundation

final class ModelManager {
    static let shared = ModelManager()

    let modelsDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MeetsVault/models")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let allModels: [(name: String, displaySize: String)] = [
        ("tiny",     "75 MB"),
        ("base",     "142 MB"),
        ("small",    "466 MB"),
        ("medium",   "1.5 GB"),
        ("large-v3", "3 GB"),
    ]

    func isDownloaded(_ name: String) -> Bool {
        let variant = "openai_whisper-\(name)"
        let modelDir = modelsDir.appendingPathComponent("argmaxinc/whisperkit-coreml/\(variant)")
        return FileManager.default.fileExists(atPath: modelDir.path)
    }

    func download(_ name: String, progress: @escaping (Double) -> Void) async throws {
        let engine = WhisperKitEngine()
        try await engine.prepare(modelName: name, progress: progress)
        var models = Settings.shared.downloadedModels
        if !models.contains(name) {
            models.append(name)
            Settings.shared.downloadedModels = models
        }
    }
}
