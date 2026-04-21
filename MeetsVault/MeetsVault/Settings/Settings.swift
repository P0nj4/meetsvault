import Foundation

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let selectedModelName = "selectedModelName"
        static let transcriptionLanguage = "transcriptionLanguage"
        static let downloadedModels = "downloadedModels"
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
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
}
