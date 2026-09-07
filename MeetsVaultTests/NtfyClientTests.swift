import XCTest
@testable import MeetsVault

/// Intercepts requests so NtfyClient can be tested with no network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    static func reset() {
        lastRequest = nil
        lastBody = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let size = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: size)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            buffer.deallocate()
            stream.close()
            Self.lastBody = data
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class NtfyClientTests: XCTestCase {

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Sends and waits until the stub has recorded a request.
    private func sendAndWait(
        serverURL: String,
        topic: String,
        title: String = "Recording in progress",
        body: String = "Weekly Sync · 01:23:45 elapsed",
        tags: String = "red_circle"
    ) {
        StubURLProtocol.reset()
        let client = NtfyClient(serverURL: serverURL, topic: topic, session: makeSession())
        let done = expectation(description: "request issued")
        client.send(title: title, body: body, tags: tags)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { done.fulfill() }
        wait(for: [done], timeout: 2.0)
    }

    func testPostsToServerSlashTopic() {
        sendAndWait(serverURL: "https://ntfy.sh", topic: "test-topic")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.absoluteString, "https://ntfy.sh/test-topic")
    }

    func testHandlesServerURLWithTrailingSlash() {
        sendAndWait(serverURL: "https://ntfy.sh/", topic: "test-topic")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.absoluteString, "https://ntfy.sh/test-topic")
    }

    func testUsesPOST() {
        sendAndWait(serverURL: "https://ntfy.sh", topic: "test-topic")
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "POST")
    }

    func testSetsTitleAndTagsHeaders() {
        sendAndWait(serverURL: "https://ntfy.sh", topic: "test-topic")
        let request = StubURLProtocol.lastRequest
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Title"), "Recording in progress")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Tags"), "red_circle")
    }

    func testSendsBodyAsUTF8PlainText() {
        sendAndWait(serverURL: "https://ntfy.sh", topic: "test-topic")
        let sent = StubURLProtocol.lastBody.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(sent, "Weekly Sync · 01:23:45 elapsed")
    }

    func testMalformedServerURLIssuesNoRequest() {
        sendAndWait(serverURL: "not a url", topic: "test-topic")
        XCTAssertNil(StubURLProtocol.lastRequest)
    }
}
