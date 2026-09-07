# ntfy status_report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `meetsvault://status_report` URL command that pushes a notification to a user-configured ntfy topic, but only while a recording is actually in progress.

**Architecture:** Four small, independently testable pieces plus wiring. `Settings` gains two keys and a pure topic-validation function. `NtfyClient` turns a message into an HTTP POST, with its `URLSession` injected so it can be tested without network. `RecordingStatusMessage` is a pure builder for the notification title/body/tags. `URLSchemeHandler` gains a `status_report` case that reads state and `Settings`, then calls the client. `MenuBarController` gains a "Phone Notifications" submenu to set the topic.

**Tech Stack:** Swift 5.10, AppKit, Foundation `URLSession`, XCTest, xcodegen. macOS 15+, Apple Silicon.

**Spec:** `docs/superpowers/specs/2026-09-07-ntfy-status-report-design.md`

## Global Constraints

- **This repo is public.** No real ntfy topic may appear in any committed file — not in code, docs, tests, or fixtures. Docs use `<your-topic>` as the placeholder.
- **Never log the ntfy topic or the full request URL.** Log host and status code only. An untracked `logs/` directory exists in the working tree.
- **The `Title` HTTP header must be ASCII.** HTTP headers cannot carry the emoji; the 🔴 comes from the ntfy tag `red_circle`.
- **Nothing in this feature may block, throw into, or otherwise disturb an active recording.** All ntfy work is fire-and-forget; every failure path is a log line and a return.
- **Silence is the signal.** Not recording, or no topic configured, means no push and no user-visible feedback of any kind.
- **New `.swift` files require `xcodegen generate --spec project.yml`** before Xcode sees them.
- Test command shape used throughout:
  `xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault -destination "platform=macOS,arch=arm64" -only-testing:MeetsVaultTests/<Suite>`

---

### Task 1: Settings keys and topic validation

**Files:**
- Modify: `MeetsVault/MeetsVault/Settings/Settings.swift`
- Test: `MeetsVaultTests/SettingsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Settings.shared.ntfyTopic: String?` (get/set; empty string reads back as `nil`)
  - `Settings.shared.ntfyServerURL: String` (get/set; defaults to `"https://ntfy.sh"`)
  - `enum NtfyTopicValidation: Equatable { case clear; case valid(String); case invalid(reason: String) }`
  - `Settings.validateNtfyTopic(_ raw: String) -> NtfyTopicValidation` (static, pure)

- [ ] **Step 1: Write the failing tests**

Add to `MeetsVaultTests/SettingsTests.swift`. Note the `tearDown` also has to clear the new keys so tests do not leak into each other or into the developer's real preferences.

```swift
    override func tearDown() {
        Settings.shared.lastCaptureMode = nil
        Settings.shared.ntfyTopic = nil
        Settings.shared.ntfyServerURL = "https://ntfy.sh"
        super.tearDown()
    }

    // MARK: - ntfyTopic storage

    func testNtfyTopicDefaultsToNil() {
        Settings.shared.ntfyTopic = nil
        XCTAssertNil(Settings.shared.ntfyTopic)
    }

    func testNtfyTopicRoundTrips() {
        Settings.shared.ntfyTopic = "test-topic"
        XCTAssertEqual(Settings.shared.ntfyTopic, "test-topic")
    }

    func testNtfyTopicEmptyStringReadsBackAsNil() {
        Settings.shared.ntfyTopic = ""
        XCTAssertNil(Settings.shared.ntfyTopic)
    }

    // MARK: - ntfyServerURL

    func testNtfyServerURLDefaultsToNtfySh() {
        Settings.shared.ntfyServerURL = "https://ntfy.sh"
        XCTAssertEqual(Settings.shared.ntfyServerURL, "https://ntfy.sh")
    }

    func testNtfyServerURLRoundTrips() {
        Settings.shared.ntfyServerURL = "https://ntfy.example.com"
        XCTAssertEqual(Settings.shared.ntfyServerURL, "https://ntfy.example.com")
    }

    // MARK: - Topic validation

    func testValidateAcceptsNormalTopic() {
        XCTAssertEqual(Settings.validateNtfyTopic("test-topic"), .valid("test-topic"))
    }

    func testValidateAcceptsUnderscoresAndDigits() {
        XCTAssertEqual(Settings.validateNtfyTopic("test_topic_42"), .valid("test_topic_42"))
    }

    func testValidateTrimsSurroundingWhitespace() {
        XCTAssertEqual(Settings.validateNtfyTopic("  test-topic  "), .valid("test-topic"))
    }

    func testValidateTreatsEmptyAsClear() {
        XCTAssertEqual(Settings.validateNtfyTopic(""), .clear)
    }

    func testValidateTreatsWhitespaceOnlyAsClear() {
        XCTAssertEqual(Settings.validateNtfyTopic("   "), .clear)
    }

    func testValidateRejectsSlash() {
        guard case .invalid = Settings.validateNtfyTopic("test/topic") else {
            return XCTFail("expected .invalid for a topic containing a slash")
        }
    }

    func testValidateRejectsInnerSpace() {
        guard case .invalid = Settings.validateNtfyTopic("test topic") else {
            return XCTFail("expected .invalid for a topic containing a space")
        }
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault \
  -destination "platform=macOS,arch=arm64" \
  -only-testing:MeetsVaultTests/SettingsTests
```
Expected: compile failure — `ntfyTopic`, `ntfyServerURL` and `validateNtfyTopic` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

In `MeetsVault/MeetsVault/Settings/Settings.swift`, add the two keys to the existing `Key` enum, next to `lastCaptureMode`:

```swift
        static let ntfyTopic = "ntfyTopic"
        static let ntfyServerURL = "ntfyServerURL"
```

Add the validation type at file scope (outside the `Settings` class):

```swift
enum NtfyTopicValidation: Equatable {
    case clear
    case valid(String)
    case invalid(reason: String)
}
```

Add the accessors and the validator inside `Settings`, following the existing accessor style:

```swift
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
            return .invalid(reason: "A topic cannot contain “/”.")
        }
        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return .invalid(reason: "A topic cannot contain spaces.")
        }
        return .valid(trimmed)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault \
  -destination "platform=macOS,arch=arm64" \
  -only-testing:MeetsVaultTests/SettingsTests
```
Expected: PASS, including the four pre-existing `lastCaptureMode` tests.

- [ ] **Step 5: Commit**

```bash
git add MeetsVault/MeetsVault/Settings/Settings.swift MeetsVaultTests/SettingsTests.swift
git commit -m "add ntfy topic and server settings with topic validation"
```

---

### Task 2: RecordingStatusMessage builder

**Files:**
- Create: `MeetsVault/MeetsVault/Notifications/RecordingStatusMessage.swift`
- Create: `MeetsVaultTests/RecordingStatusMessageTests.swift`
- Modify: `MeetsVault.xcodeproj` (regenerated, not hand-edited)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum RecordingStatusMessage`
  - `RecordingStatusMessage.title: String` — `"Recording in progress"` (ASCII)
  - `RecordingStatusMessage.tags: String` — `"red_circle"`
  - `RecordingStatusMessage.formatDuration(_ seconds: TimeInterval) -> String` → `HH:MM:SS`
  - `RecordingStatusMessage.body(sessionTitle: String?, elapsed: TimeInterval) -> String`

- [ ] **Step 1: Write the failing tests**

Create `MeetsVaultTests/RecordingStatusMessageTests.swift`:

```swift
import XCTest
@testable import MeetsVault

final class RecordingStatusMessageTests: XCTestCase {

    // MARK: - Title

    func testTitleIsASCIISoItSurvivesAnHTTPHeader() {
        XCTAssertTrue(RecordingStatusMessage.title.allSatisfy { $0.isASCII })
    }

    // MARK: - Duration formatting

    func testFormatDurationUnderAMinute() {
        XCTAssertEqual(RecordingStatusMessage.formatDuration(42), "00:00:42")
    }

    func testFormatDurationMinutesAndSeconds() {
        XCTAssertEqual(RecordingStatusMessage.formatDuration(125), "00:02:05")
    }

    func testFormatDurationOverAnHour() {
        XCTAssertEqual(RecordingStatusMessage.formatDuration(5025), "01:23:45")
    }

    func testFormatDurationClampsNegativeToZero() {
        XCTAssertEqual(RecordingStatusMessage.formatDuration(-10), "00:00:00")
    }

    // MARK: - Body

    func testBodyIncludesTitleAndElapsed() {
        let body = RecordingStatusMessage.body(sessionTitle: "Weekly Sync", elapsed: 5025)
        XCTAssertEqual(body, "Weekly Sync · 01:23:45 elapsed")
    }

    func testBodyFallsBackWhenTitleIsNil() {
        let body = RecordingStatusMessage.body(sessionTitle: nil, elapsed: 125)
        XCTAssertEqual(body, "00:02:05 elapsed")
    }

    func testBodyFallsBackWhenTitleIsEmpty() {
        let body = RecordingStatusMessage.body(sessionTitle: "", elapsed: 125)
        XCTAssertEqual(body, "00:02:05 elapsed")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault \
  -destination "platform=macOS,arch=arm64" \
  -only-testing:MeetsVaultTests/RecordingStatusMessageTests
```
Expected: build failure — the test file is not yet in the project, and `RecordingStatusMessage` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `MeetsVault/MeetsVault/Notifications/RecordingStatusMessage.swift`:

```swift
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
```

- [ ] **Step 4: Regenerate the Xcode project**

Both new files must be picked up by the glob before Xcode can see them.

Run:
```bash
xcodegen generate --spec project.yml
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault \
  -destination "platform=macOS,arch=arm64" \
  -only-testing:MeetsVaultTests/RecordingStatusMessageTests
```
Expected: PASS, 8 tests.

- [ ] **Step 6: Commit**

```bash
git add MeetsVault/MeetsVault/Notifications/RecordingStatusMessage.swift \
        MeetsVaultTests/RecordingStatusMessageTests.swift \
        MeetsVault.xcodeproj
git commit -m "add RecordingStatusMessage builder for ntfy status pushes"
```

---

### Task 3: NtfyClient

**Files:**
- Create: `MeetsVault/MeetsVault/Notifications/NtfyClient.swift`
- Create: `MeetsVaultTests/NtfyClientTests.swift`
- Modify: `MeetsVault.xcodeproj` (regenerated)

**Interfaces:**
- Consumes: nothing from earlier tasks (server and topic are passed in, not read from `Settings`).
- Produces:
  - `final class NtfyClient`
  - `init(serverURL: String, topic: String, session: URLSession = .shared)`
  - `func send(title: String, body: String, tags: String)` — fire-and-forget, returns immediately

- [ ] **Step 1: Write the failing tests**

Create `MeetsVaultTests/NtfyClientTests.swift`. The `URLProtocol` stub is what lets this run with no network: it intercepts the request, records it, and returns a canned 200.

Note the `URLProtocol` subclass reads the body from `httpBodyStream`, not `httpBody` — `URLSession` converts the body to a stream before the protocol sees it, so reading `httpBody` here returns `nil`.

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault \
  -destination "platform=macOS,arch=arm64" \
  -only-testing:MeetsVaultTests/NtfyClientTests
```
Expected: build failure — `NtfyClient` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `MeetsVault/MeetsVault/Notifications/NtfyClient.swift`:

```swift
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

        let host = components.host ?? "unknown"

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue(tags, forHTTPHeaderField: "Tags")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        session.dataTask(with: request) { _, response, error in
            if let error {
                NSLog("[MeetsVault] ntfy: request to %@ failed: %@", host, error.localizedDescription)
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if !(200...299).contains(status) {
                NSLog("[MeetsVault] ntfy: %@ returned status %d", host, status)
            }
        }.resume()
    }
}
```

- [ ] **Step 4: Regenerate the Xcode project**

Run:
```bash
xcodegen generate --spec project.yml
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault \
  -destination "platform=macOS,arch=arm64" \
  -only-testing:MeetsVaultTests/NtfyClientTests
```
Expected: PASS, 6 tests.

- [ ] **Step 6: Verify no topic leaks into the log statements**

Run:
```bash
grep -n "NSLog" MeetsVault/MeetsVault/Notifications/NtfyClient.swift
```
Expected: every `NSLog` interpolates `host` or a status code — none references `topic` or `url`.

- [ ] **Step 7: Commit**

```bash
git add MeetsVault/MeetsVault/Notifications/NtfyClient.swift \
        MeetsVaultTests/NtfyClientTests.swift \
        MeetsVault.xcodeproj
git commit -m "add NtfyClient for fire-and-forget ntfy publishing"
```

---

### Task 4: Wire `meetsvault://status_report` into the URL handler

**Files:**
- Modify: `MeetsVault/MeetsVault/Recording/AudioRecorder.swift:30-31`
- Modify: `MeetsVault/MeetsVault/URLScheme/URLSchemeHandler.swift`

**Interfaces:**
- Consumes: `Settings.shared.ntfyTopic`, `Settings.shared.ntfyServerURL` (Task 1); `RecordingStatusMessage.title` / `.tags` / `.body(sessionTitle:elapsed:)` (Task 2); `NtfyClient(serverURL:topic:session:)` and `send(title:body:tags:)` (Task 3).
- Produces: `AudioRecorder.sessionTitle: String?` and `AudioRecorder.sessionStartDate: Date?` become readable outside the class.

There is no unit test for this task. `URLSchemeHandler`'s existing `start` and `stop` cases have none either — the type is AppKit-coupled wiring, and all the logic worth testing was extracted into Tasks 1–3. Verification is the manual matrix in Step 4.

- [ ] **Step 1: Expose the recorder's session metadata**

In `MeetsVault/MeetsVault/Recording/AudioRecorder.swift`, change these two stored properties from `private` to `private(set)`. Leave the other `session*` properties, the state machine, and the delegate protocol untouched.

```swift
    private(set) var sessionTitle: String?
    private(set) var sessionStartDate: Date?
```

- [ ] **Step 2: Add the `status_report` case**

In `MeetsVault/MeetsVault/URLScheme/URLSchemeHandler.swift`, add a new case to the existing `switch url.host`, after the `stop` case and before `default`:

```swift
        case "status_report":
            guard let recorder else { return }
            guard recorder.state == .recording else {
                NSLog("[MeetsVault] status_report ignored — not recording")
                return
            }
            guard let topic = Settings.shared.ntfyTopic else {
                NSLog("[MeetsVault] status_report ignored — no ntfy topic configured")
                return
            }
            let elapsed = Date().timeIntervalSince(recorder.sessionStartDate ?? Date())
            let client = NtfyClient(serverURL: Settings.shared.ntfyServerURL, topic: topic)
            client.send(
                title: RecordingStatusMessage.title,
                body: RecordingStatusMessage.body(
                    sessionTitle: recorder.sessionTitle,
                    elapsed: elapsed
                ),
                tags: RecordingStatusMessage.tags
            )
```

Unlike `start` and `stop`, this case takes no prompt closure and presents no UI, so `AppDelegate.handleGetURLEvent` needs no change.

- [ ] **Step 3: Build and run the full test suite**

Run:
```bash
xcodebuild -project MeetsVault.xcodeproj -scheme MeetsVault \
  -configuration Release -destination "platform=macOS,arch=arm64" \
  -derivedDataPath build build

xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault \
  -destination "platform=macOS,arch=arm64"
```
Expected: build succeeds; every suite passes, including the pre-existing `FilenameBuilder`, `TranscriptCleaner`, `LanguageCode`, `TranscriptWriter` and `TranscriptDeduplicator` tests.

- [ ] **Step 4: Manual verification**

Set a topic first (this is the only way to configure it until Task 5 lands):

```bash
defaults write com.germanpereyra.meetsvault ntfyTopic <your-topic>
```

Launch `build/Build/Products/Release/MeetsVault.app`, subscribe the phone to `<your-topic>` in the ntfy app, then check all four rows:

| State | Topic set? | Expected |
|---|---|---|
| idle | yes | nothing on the phone; log says "not recording" |
| recording | yes | push arrives: title "Recording in progress", body `<meeting> · HH:MM:SS elapsed`, 🔴 |
| recording | no (`defaults delete com.germanpereyra.meetsvault ntfyTopic`) | nothing; log says "no ntfy topic configured" |
| transcribing | yes | nothing on the phone |

Fire it with:
```bash
open "meetsvault://status_report"
```

- [ ] **Step 5: Commit**

```bash
git add MeetsVault/MeetsVault/Recording/AudioRecorder.swift \
        MeetsVault/MeetsVault/URLScheme/URLSchemeHandler.swift
git commit -m "add meetsvault://status_report URL command"
```

---

### Task 5: "Phone Notifications" menu-bar submenu

**Files:**
- Modify: `MeetsVault/MeetsVault/MenuBar/MenuBarController.swift`

**Interfaces:**
- Consumes: `Settings.shared.ntfyTopic`, `Settings.validateNtfyTopic(_:)`, `NtfyTopicValidation` (Task 1).
- Produces: nothing consumed by later tasks.

No unit test: this is `NSAlert` and `NSMenu` construction, matching how `makeLanguageSubmenu` and `makeModelSubmenu` are handled today. The validation logic underneath it is already covered by Task 1.

- [ ] **Step 1: Add the submenu builder**

In `MeetsVault/MeetsVault/MenuBar/MenuBarController.swift`, add alongside the existing `makeModelSubmenu()`:

```swift
    private func makeNotificationsSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Phone Notifications", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.autoenablesItems = false

        let topic = Settings.shared.ntfyTopic
        let statusItem = NSMenuItem(
            title: "Topic: \(topic ?? "not set")",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        sub.addItem(statusItem)

        let setItem = NSMenuItem(title: "Set ntfy Topic…", action: #selector(setNtfyTopic), keyEquivalent: "")
        setItem.target = self
        sub.addItem(setItem)

        item.submenu = sub
        return item
    }
```

- [ ] **Step 2: Add the alert action**

Add near the other `@objc` menu actions in the same file:

```swift
    @objc private func setNtfyTopic() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "ntfy topic"
        alert.informativeText = "MeetsVault posts to this topic when you ask for a status report. Subscribe your phone to the same topic in the ntfy app. Leave it empty to turn phone notifications off."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = Settings.shared.ntfyTopic ?? ""
        field.placeholderString = "my-topic"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        switch Settings.validateNtfyTopic(field.stringValue) {
        case .clear:
            Settings.shared.ntfyTopic = nil
            buildMenu()
        case .valid(let topic):
            Settings.shared.ntfyTopic = topic
            buildMenu()
        case .invalid(let reason):
            let error = NSAlert()
            error.messageText = "That topic is not valid"
            error.informativeText = reason
            error.addButton(withTitle: "OK")
            error.runModal()
        }
    }
```

- [ ] **Step 3: Insert the submenu into the menu**

In `buildMenu()`, add it immediately after the model submenu:

```swift
        menu.addItem(makeLanguageSubmenu())
        menu.addItem(makeModelSubmenu())
        menu.addItem(makeNotificationsSubmenu())
```

- [ ] **Step 4: Build and run the full test suite**

Run:
```bash
xcodebuild -project MeetsVault.xcodeproj -scheme MeetsVault \
  -configuration Release -destination "platform=macOS,arch=arm64" \
  -derivedDataPath build build

xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault \
  -destination "platform=macOS,arch=arm64"
```
Expected: build succeeds, all suites pass.

- [ ] **Step 5: Manual verification**

Launch `build/Build/Products/Release/MeetsVault.app` and check:

- Menu shows **Phone Notifications** with `Topic: not set` when nothing is configured.
- "Set ntfy Topic…" opens the alert with the field focused.
- Saving `test-topic` updates the status line to `Topic: test-topic`.
- Reopening the alert prefills `test-topic`.
- Saving `bad/topic` shows the "cannot contain “/”" error and leaves the stored topic unchanged.
- Saving `bad topic` shows the "cannot contain spaces" error.
- Saving an empty field returns the line to `Topic: not set`, and `meetsvault://status_report` while recording then does nothing.
- Cancel leaves the stored value untouched.

- [ ] **Step 6: Commit**

```bash
git add MeetsVault/MeetsVault/MenuBar/MenuBarController.swift
git commit -m "add Phone Notifications submenu to set the ntfy topic"
```

---

### Task 6: Documentation

**Files:**
- Modify: `README.md:18` (Features), `README.md:82-91` (URL scheme), `README.md:3` (tagline)
- Modify: `docs/USER_MANUAL.md:196-226` (URL scheme), `docs/USER_MANUAL.md:256` (Privacy)
- Modify: `docs/USER_MANUAL.es.md:196-226` (URL scheme), `docs/USER_MANUAL.es.md:256` (Privacy)
- Modify: `CLAUDE.md:19` (project description), `CLAUDE.md:79` (URL scheme), `CLAUDE.md` settings-keys list

**Interfaces:**
- Consumes: the finished behavior from Tasks 1–5.
- Produces: nothing.

`CLAUDE.md` requires all three user-facing docs to be updated in the same commit as a user-visible change. The privacy claim is the delicate part: it is currently false once this ships, and must be corrected rather than quietly left alone.

**Never write a real topic into any of these files. Use `<your-topic>`.**

- [ ] **Step 1: Update `README.md`**

Add to the Features list, after the existing URL-scheme bullet:

```markdown
- Check from your phone whether a recording is still running, via an optional [ntfy](https://ntfy.sh) push (`meetsvault://status_report`)
```

Add to the URL scheme section, after the `stop` example:

```markdown
# Ask whether a recording is in progress (pushes to ntfy only if one is)
open 'meetsvault://status_report'
```

And below that block:

```markdown
> `status_report` is silent unless a recording is actually in progress **and** you have set an ntfy topic under **Phone Notifications** in the menu bar. No push means no recording. Subscribe your phone to the same topic in the ntfy app; the topic is stored only on your Mac and never leaves it except as the address of the push.
```

Update the tagline on line 3 — "No cloud" is no longer unconditionally true:

```markdown
A native macOS menu-bar app that records meetings and transcribes them locally using [WhisperKit](https://github.com/argmaxinc/WhisperKit). No cloud transcription, no subscription, fully private.
```

- [ ] **Step 2: Update `docs/USER_MANUAL.md`**

In the URL scheme section (around line 196–226), add `status_report` next to the existing `start` and `stop` entries:

```markdown
### Check whether a recording is running

```
meetsvault://status_report
```

Sends a notification to your phone **only if a recording is currently in progress**. If nothing is being recorded, nothing happens — no notification is the answer. Useful when you have walked away from your Mac and cannot remember whether you left a recording running.

This requires a one-time setup, described below. Without it, the command does nothing.

### Setting up phone notifications

1. Install the [ntfy](https://ntfy.sh) app on your phone.
2. In the app, subscribe to a topic. Pick a long, hard-to-guess name — anyone who knows the topic name can read the notifications sent to it.
3. On your Mac, click the MeetsVault menu-bar icon and choose **Phone Notifications → Set ntfy Topic…**.
4. Type the same topic name and click **Save**. The submenu now shows `Topic: <your-topic>`.

To turn phone notifications off, open the same dialog and save an empty field.

The topic is stored only on your Mac. The only information that ever leaves it is the notification itself — the meeting title and how long the recording has been running — and only when you explicitly ask for a status report.
```

Rewrite the Privacy paragraph (line 256), which currently claims no network calls at all:

```markdown
MeetsVault makes no network calls during recording or transcription. It connects to the internet in exactly two cases: when downloading a Whisper model for the first time (models come from Hugging Face), and — only if you have configured an ntfy topic — when you explicitly ask for a status report with `meetsvault://status_report`. That status push contains the meeting title and how long the recording has been running; it is off by default and never fires on its own. Your audio and transcripts are never sent anywhere.
```

- [ ] **Step 3: Update `docs/USER_MANUAL.es.md`**

Mirror every Step 2 change in Spanish, at the matching locations (URL scheme section around line 196–226, Privacy around line 256). The Spanish manual is a mirror of the English one — do not let them drift.

The Privacy paragraph (line 256) becomes:

```markdown
MeetsVault no realiza ninguna llamada de red durante la grabación o la transcripción. Se conecta a internet en exactamente dos casos: al descargar un modelo Whisper por primera vez (los modelos vienen de Hugging Face) y — solo si configuraste un topic de ntfy — cuando pides explícitamente un reporte de estado con `meetsvault://status_report`. Ese aviso contiene el título de la reunión y cuánto lleva grabando; está desactivado por defecto y nunca se dispara solo. Tu audio y tus transcripciones no se envían nunca a ningún lado.
```

The menu item names stay in English (`Phone Notifications`, `Set ntfy Topic…`) because the app's UI is in English; the surrounding prose is Spanish. Check how the existing Spanish manual refers to other menu items and follow the same convention.

- [ ] **Step 4: Update `CLAUDE.md`**

Three edits:

- Line 19: change "No cloud, no network calls during recording or transcription" to note the optional, off-by-default ntfy status push.
- Line 79 (URL scheme paragraph): document `status_report` — pushes to ntfy only when `state == .recording` and a topic is configured; silent otherwise; presents no UI and takes no prompt closure.
- Settings keys list: add `ntfyTopic` (topic name, `nil` = feature off) and `ntfyServerURL` (defaults to `https://ntfy.sh`, no UI).

- [ ] **Step 5: Verify no real topic was committed**

Run:
```bash
git diff --cached | grep -in "ntfytopic" | grep -v "your-topic\|test-topic\|my-topic\|not set"
```
Expected: no output. Any hit is a real topic about to be published — remove it before committing.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/USER_MANUAL.md docs/USER_MANUAL.es.md CLAUDE.md
git commit -m "document meetsvault://status_report and correct the network-calls claim"
```

---

## Done when

- `meetsvault://status_report` pushes to ntfy while recording with a topic set, and is silent in every other combination of state and configuration.
- The topic is settable from the menu bar and survives a relaunch.
- `xcodebuild test` passes in full.
- No real ntfy topic appears anywhere in the repository.
- README, both manuals, and `CLAUDE.md` describe the feature and no longer claim the app makes no network calls.
