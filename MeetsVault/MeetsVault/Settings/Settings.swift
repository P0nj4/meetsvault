import Foundation

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let selectedModelName = "selectedModelName"
        static let transcriptionLanguage = "transcriptionLanguage"
        static let downloadedModels = "downloadedModels"
        static let meetingsDirectoryPath = "meetingsDirectoryPath"
    }

    private static var onboardingFlagURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MeetsVault/onboarding_complete")
    }

    var hasCompletedOnboarding: Bool {
        get { FileManager.default.fileExists(atPath: Self.onboardingFlagURL.path) }
        set {
            if newValue {
                let dir = Self.onboardingFlagURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: Self.onboardingFlagURL.path, contents: nil)
            } else {
                try? FileManager.default.removeItem(at: Self.onboardingFlagURL)
            }
        }
    }

    var selectedModelName: String {
        get { defaults.string(forKey: Key.selectedModelName) ?? "small" }
        set { defaults.set(newValue, forKey: Key.selectedModelName) }
    }

    var transcriptionLanguage: String {
        get { defaults.string(forKey: Key.transcriptionLanguage) ?? "en" }
        set { defaults.set(newValue, forKey: Key.transcriptionLanguage) }
    }

    var downloadedModels: [String] {
        get { defaults.stringArray(forKey: Key.downloadedModels) ?? [] }
        set { defaults.set(newValue, forKey: Key.downloadedModels) }
    }

    static let defaultMeetingsDirectory: URL =
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Meetings")

    var meetingsDirectory: URL {
        get {
            if let path = defaults.string(forKey: Key.meetingsDirectoryPath) {
                return URL(fileURLWithPath: path)
            }
            return Settings.defaultMeetingsDirectory
        }
        set { defaults.set(newValue.path, forKey: Key.meetingsDirectoryPath) }
    }
}
