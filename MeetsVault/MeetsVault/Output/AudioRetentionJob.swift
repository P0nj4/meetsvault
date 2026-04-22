import Foundation

enum AudioRetentionJob {
    static func run() {
        let meetingsDir = Settings.shared.meetingsDirectory
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: meetingsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        for url in items where url.pathExtension == "wav" {
            guard let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  modDate < cutoff else { continue }
            try? FileManager.default.removeItem(at: url)
            NSLog("[MeetsVault] AudioRetentionJob: deleted %@", url.lastPathComponent)
        }
    }
}
