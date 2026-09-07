import Foundation

enum NtfyTopicValidation: Equatable {
    case clear
    case valid(String)
    case invalid(reason: String)
}

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let selectedModelName = "selectedModelName"
        static let transcriptionLanguage = "transcriptionLanguage"
        static let downloadedModels = "downloadedModels"
        static let meetingsDirectoryPath = "meetingsDirectoryPath"
        static let lastCaptureMode = "lastCaptureMode"
        static let ntfyTopic = "ntfyTopic"
        static let ntfyServerURL = "ntfyServerURL"
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

    private static var termsFlagURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MeetsVault/terms_accepted_v\(Terms.version)")
    }

    var hasAcceptedTerms: Bool {
        get { FileManager.default.fileExists(atPath: Self.termsFlagURL.path) }
        set {
            if newValue {
                let dir = Self.termsFlagURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: Self.termsFlagURL.path, contents: nil)
            } else {
                try? FileManager.default.removeItem(at: Self.termsFlagURL)
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

    var lastCaptureMode: CaptureMode? {
        get {
            guard let raw = defaults.string(forKey: Key.lastCaptureMode) else { return nil }
            return CaptureMode(rawValue: raw)
        }
        set { defaults.set(newValue?.rawValue, forKey: Key.lastCaptureMode) }
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

    var ntfyTopic: String? {
        get {
            guard let t = defaults.string(forKey: Key.ntfyTopic), !t.isEmpty else { return nil }
            return t
        }
        set { defaults.set(newValue, forKey: Key.ntfyTopic) }
    }

    var ntfyServerURL: String {
        get { defaults.string(forKey: Key.ntfyServerURL) ?? "https://ntfy.sh" }
        set { defaults.set(newValue, forKey: Key.ntfyServerURL) }
    }

    /// Pure validation for a user-entered ntfy topic.
    /// ntfy topics are alphanumerics plus `-` and `_`; a `/` would silently
    /// change the request path, which is the failure worth guarding against.
    static func validateNtfyTopic(_ raw: String) -> NtfyTopicValidation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .clear }
        if trimmed.contains("/") {
            return .invalid(reason: "A topic cannot contain \"/\".")
        }
        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return .invalid(reason: "A topic cannot contain spaces.")
        }
        return .valid(trimmed)
    }
}
