import Foundation

enum URLSchemeHandler {
    static func handle(_ url: URL, recorder: AudioRecorder?) {
        guard url.scheme == "meetsvault" else { return }

        let title = url.queryItem("title")

        switch url.host {
        case "start":
            NSLog("[MeetsVault] URL command: start, title=%@", title ?? "(none)")
            // wired to recorder in Phase 3
        case "stop":
            NSLog("[MeetsVault] URL command: stop")
            // wired to recorder in Phase 3
        default:
            NSLog("[MeetsVault] Unknown URL command: %@", url.absoluteString)
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
