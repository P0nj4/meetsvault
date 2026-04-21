import Foundation
import AppKit

enum URLSchemeHandler {
    static func handle(_ url: URL, recorder: AudioRecorder?) {
        guard url.scheme == "meetsvault" else { return }

        let title = url.queryItem("title")

        switch url.host {
        case "start":
            guard let recorder else { return }
            guard recorder.state == .idle else {
                NSLog("[MeetsVault] URL start ignored — already recording or transcribing")
                postNotification(title: "Already recording", body: "Stop the current recording first.")
                return
            }
            Task {
                do {
                    try await recorder.start(title: title)
                } catch {
                    NSLog("[MeetsVault] Start failed: %@", error.localizedDescription)
                    postNotification(title: "Could not start recording", body: error.localizedDescription)
                }
            }

        case "stop":
            guard let recorder else { return }
            guard recorder.state == .recording else {
                NSLog("[MeetsVault] URL stop ignored — not recording")
                postNotification(title: "Nothing to stop", body: "MeetsVault is not currently recording.")
                return
            }
            Task { await recorder.stop() }

        default:
            NSLog("[MeetsVault] Unknown URL command: %@", url.absoluteString)
            postNotification(title: "Unknown command", body: url.absoluteString)
        }
    }

    private static func postNotification(title: String, body: String) {
        // Lightweight NSUserNotification fallback for early phases;
        // replaced by NotificationManager in Phase 5.
        DispatchQueue.main.async {
            let notification = NSUserNotification()
            notification.title = title
            notification.informativeText = body
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
}

private extension URL {
    func queryItem(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
