import Foundation
import UserNotifications
import AppKit

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private let categoryID = "TRANSCRIPT_READY"
    private let openActionID = "OPEN"

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        let openAction = UNNotificationAction(identifier: openActionID, title: "Open", options: .foreground)
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { NSLog("[MeetsVault] Notification auth error: %@", error.localizedDescription) }
        }
    }

    func postTranscriptReady(fileURL: URL, title: String, duration: TimeInterval) {
        requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = "Transcript ready"
        content.body = "\(title) · \(formatDuration(duration))"
        content.categoryIdentifier = categoryID
        content.userInfo = ["filePath": fileURL.path]
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func postRecordingReminder() {
        requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = "Recording still in progress"
        content.body = "MeetsVault is still recording. Don't forget to stop it."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "recording-reminder",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func postInfo(_ title: String, body: String = "") {
        let content = UNMutableNotificationContent()
        content.title = title
        if !body.isEmpty { content.body = body }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { NSLog("[MeetsVault] Notification error: %@", error.localizedDescription) }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let path = response.notification.request.content.userInfo["filePath"] as? String {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
