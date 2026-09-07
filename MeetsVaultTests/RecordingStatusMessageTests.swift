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
