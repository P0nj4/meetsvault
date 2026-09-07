import XCTest
@testable import MeetsVault

final class SettingsTests: XCTestCase {

    override func tearDown() {
        Settings.shared.lastCaptureMode = nil
        Settings.shared.ntfyTopic = nil
        Settings.shared.ntfyServerURL = "https://ntfy.sh"
        super.tearDown()
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
}
