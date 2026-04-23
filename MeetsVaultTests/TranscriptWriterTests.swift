import XCTest
@testable import MeetsVault

final class TranscriptWriterTests: XCTestCase {

    // MARK: - formatTimestamp

    func testFormatTimestampZero() {
        XCTAssertEqual(TranscriptWriter.formatTimestamp(0), "00:00:00")
    }

    func testFormatTimestampSeconds() {
        XCTAssertEqual(TranscriptWriter.formatTimestamp(90), "00:01:30")
    }

    func testFormatTimestampHours() {
        XCTAssertEqual(TranscriptWriter.formatTimestamp(3661), "01:01:01")
    }

    // MARK: - formatDuration

    func testFormatDurationZero() {
        XCTAssertEqual(TranscriptWriter.formatDuration(0), "00:00:00")
    }

    func testFormatDurationMinutes() {
        XCTAssertEqual(TranscriptWriter.formatDuration(3600), "01:00:00")
    }

    // MARK: - buildMarkdown

    private func makeDate(hour: Int, minute: Int, second: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 6; comps.day = 1
        comps.hour = hour; comps.minute = minute; comps.second = second
        return Calendar.current.date(from: comps)!
    }

    private func seg(_ start: Double, _ end: Double, _ text: String) -> TranscriptSegment {
        TranscriptSegment(startSeconds: start, endSeconds: end, text: text, speaker: .you)
    }

    func testBuildMarkdownFrontMatter() {
        let start = makeDate(hour: 9, minute: 0, second: 0)
        let end = makeDate(hour: 9, minute: 30, second: 0)
        let md = TranscriptWriter.buildMarkdown(
            title: "Weekly Sync",
            startedAt: start,
            endedAt: end,
            language: "en",
            modelName: "small",
            audioFileName: "meeting.wav",
            segments: []
        )
        XCTAssertTrue(md.contains("title: Weekly Sync"), md)
        XCTAssertTrue(md.contains("language: en"), md)
        XCTAssertTrue(md.contains("model: whisperkit-small"), md)
        XCTAssertTrue(md.contains("audio_file: meeting.wav"), md)
        XCTAssertTrue(md.contains("---"), md)
    }

    func testBuildMarkdownSegmentTimestamps() {
        let start = makeDate(hour: 10, minute: 0, second: 0)
        let end = makeDate(hour: 10, minute: 5, second: 0)
        let segments = [seg(0, 5, "Hello world"), seg(10, 15, "Goodbye world")]
        let md = TranscriptWriter.buildMarkdown(
            title: "Test",
            startedAt: start,
            endedAt: end,
            language: "en",
            modelName: "small",
            audioFileName: "test.wav",
            segments: segments
        )
        XCTAssertTrue(md.contains("[00:00:00]"), md)
        XCTAssertTrue(md.contains("Hello world"), md)
    }

    func testBuildMarkdownEmptySegments() {
        let start = makeDate(hour: 8, minute: 0, second: 0)
        let end = makeDate(hour: 8, minute: 1, second: 0)
        let md = TranscriptWriter.buildMarkdown(
            title: "Empty",
            startedAt: start,
            endedAt: end,
            language: "en",
            modelName: "tiny",
            audioFileName: "empty.wav",
            segments: []
        )
        XCTAssertTrue(md.contains("# Empty"), md)
        XCTAssertTrue(md.contains("## Transcript"), md)
        XCTAssertFalse(md.contains("[00:"), "No timestamps expected for empty segments")
    }
}
