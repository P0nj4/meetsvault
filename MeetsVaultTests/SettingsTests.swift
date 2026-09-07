import XCTest
@testable import MeetsVault

final class SettingsTests: XCTestCase {

    // Tests run inside the app target, so UserDefaults.standard resolves to the
    // developer's real com.germanpereyra.meetsvault domain. Save whatever was
    // there before each test and restore it after, so a test run never
    // clobbers the developer's real preferences (e.g. their ntfy topic).
    private var savedLastCaptureMode: String?
    private var savedNtfyTopic: String?
    private var savedNtfyServerURL: String?

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        savedLastCaptureMode = defaults.string(forKey: "lastCaptureMode")
        savedNtfyTopic = defaults.string(forKey: "ntfyTopic")
        savedNtfyServerURL = defaults.string(forKey: "ntfyServerURL")
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        restore(key: "lastCaptureMode", value: savedLastCaptureMode, in: defaults)
        restore(key: "ntfyTopic", value: savedNtfyTopic, in: defaults)
        restore(key: "ntfyServerURL", value: savedNtfyServerURL, in: defaults)
        super.tearDown()
    }

    /// Restores a key to its pre-test state, distinguishing "was absent" from
    /// "was present but empty" — an absent key must stay absent, not be
    /// written as an empty/placeholder value.
    private func restore(key: String, value: String?, in defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func testLastCaptureModeDefaultsToNil() {
        Settings.shared.lastCaptureMode = nil
        XCTAssertNil(Settings.shared.lastCaptureMode)
    }

    func testLastCaptureModeRoundTripsMicOnly() {
        Settings.shared.lastCaptureMode = .micOnly
        XCTAssertEqual(Settings.shared.lastCaptureMode, .micOnly)
    }

    func testLastCaptureModeRoundTripsMicAndSystem() {
        Settings.shared.lastCaptureMode = .micAndSystem
        XCTAssertEqual(Settings.shared.lastCaptureMode, .micAndSystem)
    }

    func testLastCaptureModeOverwritesPreviousValue() {
        Settings.shared.lastCaptureMode = .micOnly
        Settings.shared.lastCaptureMode = .micAndSystem
        XCTAssertEqual(Settings.shared.lastCaptureMode, .micAndSystem)
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
        UserDefaults.standard.removeObject(forKey: "ntfyServerURL")
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

    func testValidateRejectsTopicLongerThan64Characters() {
        let tooLong = String(repeating: "a", count: 65)
        guard case .invalid = Settings.validateNtfyTopic(tooLong) else {
            return XCTFail("expected .invalid for a topic longer than 64 characters")
        }
    }

    func testValidateAccepts64CharacterTopic() {
        let boundary = String(repeating: "a", count: 64)
        XCTAssertEqual(Settings.validateNtfyTopic(boundary), .valid(boundary))
    }

    func testValidateRejectsQuestionMark() {
        guard case .invalid = Settings.validateNtfyTopic("test?topic") else {
            return XCTFail("expected .invalid for a topic containing \"?\"")
        }
    }

    func testValidateRejectsHash() {
        guard case .invalid = Settings.validateNtfyTopic("test#topic") else {
            return XCTFail("expected .invalid for a topic containing \"#\"")
        }
    }

    func testValidateRejectsPercent() {
        guard case .invalid = Settings.validateNtfyTopic("test%topic") else {
            return XCTFail("expected .invalid for a topic containing \"%\"")
        }
    }

    func testValidateRejectsNonASCII() {
        guard case .invalid = Settings.validateNtfyTopic("tópico") else {
            return XCTFail("expected .invalid for a non-ASCII topic")
        }
    }
}
