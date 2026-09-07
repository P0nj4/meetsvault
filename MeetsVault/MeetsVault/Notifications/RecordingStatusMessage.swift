import Foundation

/// Pure builder for the "you are still recording" push sent to ntfy.
/// Kept free of AppKit and URLSession so it can be unit-tested directly.
enum RecordingStatusMessage {

    /// Sent as the HTTP `Title` header, which must be ASCII.
    /// The 🔴 the user sees comes from `tags`, not from here.
    static let title = "Recording in progress"

    /// ntfy renders `red_circle` as 🔴 in the notification.
    static let tags = "red_circle"

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    static func body(sessionTitle: String?, elapsed: TimeInterval) -> String {
        let duration = formatDuration(elapsed)
        guard let sessionTitle, !sessionTitle.isEmpty else {
            return "\(duration) elapsed"
        }
        return "\(sessionTitle) · \(duration) elapsed"
    }
}
