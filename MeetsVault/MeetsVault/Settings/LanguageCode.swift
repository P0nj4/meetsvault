import Foundation

struct LanguageCode: Identifiable {
    let code: String
    let displayName: String
    var id: String { code }
}

extension LanguageCode {
    static let top: [LanguageCode] = [
        LanguageCode(code: "en", displayName: "English"),
        LanguageCode(code: "es", displayName: "Spanish"),
        LanguageCode(code: "fr", displayName: "French"),
        LanguageCode(code: "de", displayName: "German"),
        LanguageCode(code: "pt", displayName: "Portuguese"),
        LanguageCode(code: "it", displayName: "Italian"),
        LanguageCode(code: "ja", displayName: "Japanese"),
        LanguageCode(code: "zh", displayName: "Chinese"),
        LanguageCode(code: "ko", displayName: "Korean"),
        LanguageCode(code: "ru", displayName: "Russian"),
    ]

    // Full list of Whisper-supported languages
    static let all: [LanguageCode] = top + [
        LanguageCode(code: "ar", displayName: "Arabic"),
        LanguageCode(code: "cs", displayName: "Czech"),
        LanguageCode(code: "da", displayName: "Danish"),
        LanguageCode(code: "nl", displayName: "Dutch"),
        LanguageCode(code: "fi", displayName: "Finnish"),
        LanguageCode(code: "el", displayName: "Greek"),
        LanguageCode(code: "he", displayName: "Hebrew"),
        LanguageCode(code: "hi", displayName: "Hindi"),
        LanguageCode(code: "hu", displayName: "Hungarian"),
        LanguageCode(code: "id", displayName: "Indonesian"),
        LanguageCode(code: "ms", displayName: "Malay"),
        LanguageCode(code: "no", displayName: "Norwegian"),
        LanguageCode(code: "pl", displayName: "Polish"),
        LanguageCode(code: "ro", displayName: "Romanian"),
        LanguageCode(code: "sk", displayName: "Slovak"),
        LanguageCode(code: "sv", displayName: "Swedish"),
        LanguageCode(code: "th", displayName: "Thai"),
        LanguageCode(code: "tr", displayName: "Turkish"),
        LanguageCode(code: "uk", displayName: "Ukrainian"),
        LanguageCode(code: "vi", displayName: "Vietnamese"),
    ]
}
