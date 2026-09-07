import Foundation

/// Publishes a single message to an ntfy topic.
///
/// Server and topic are injected rather than read from `Settings`, so this type
/// has no global dependencies and can be tested against a stubbed URLSession.
///
/// Logging deliberately never includes the topic or the full URL: with an
/// unauthenticated topic, the topic name is the only thing protecting the
/// channel, and this repository is public.
final class NtfyClient {

    private let serverURL: String
    private let topic: String
    private let session: URLSession

    init(serverURL: String, topic: String, session: URLSession = .shared) {
        self.serverURL = serverURL
        self.topic = topic
        self.session = session
    }

    /// Fire-and-forget. Returns immediately; failures are logged and discarded
    /// so nothing here can disturb an active recording.
    func send(title: String, body: String, tags: String) {
        guard var components = URLComponents(string: serverURL), components.host != nil else {
            NSLog("[MeetsVault] ntfy: malformed server URL — skipping")
            return
        }

        let base = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        components.path = base + "/" + topic

        guard let url = components.url else {
            NSLog("[MeetsVault] ntfy: could not build request URL — skipping")
            return
        }

        let host = components.host!

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue(tags, forHTTPHeaderField: "Tags")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        session.dataTask(with: request) { _, response, error in
            if let error {
                let nsError = error as NSError
                NSLog("[MeetsVault] ntfy: request to %@ failed: domain=%@ code=%d", host, nsError.domain, nsError.code)
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if !(200...299).contains(status) {
                NSLog("[MeetsVault] ntfy: %@ returned status %d", host, status)
            }
        }.resume()
    }
}
