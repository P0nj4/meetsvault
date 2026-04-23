import XCTest
@testable import MeetsVault

final class TranscriptCleanerTests: XCTestCase {

    // MARK: - stripTokens

    func testStripTokensRemovesWhisperTokens() {
        let input = "<|startoftranscript|>Hello<|en|>"
        XCTAssertEqual(TranscriptCleaner.stripTokens(input), "Hello")
    }

    func testStripTokensCollapsesWhitespace() {
        let input = "Hello   world"
        XCTAssertEqual(TranscriptCleaner.stripTokens(input), "Hello world")
    }

    func testStripTokensTrims() {
        let input = "  Hello world  "
        XCTAssertEqual(TranscriptCleaner.stripTokens(input), "Hello world")
    }

    func testStripTokensPlainText() {
        let input = "No tokens here."
        XCTAssertEqual(TranscriptCleaner.stripTokens(input), "No tokens here.")
    }

    func testStripTokensMultipleTokens() {
        let input = "<|0.00|>Hey<|1.50|> there<|notimestamps|>"
        XCTAssertEqual(TranscriptCleaner.stripTokens(input), "Hey there")
    }

    // MARK: - merge

    private func seg(_ start: Double, _ end: Double, _ text: String, _ speaker: Speaker = .you) -> TranscriptSegment {
        TranscriptSegment(startSeconds: start, endSeconds: end, text: text, speaker: speaker)
    }

    func testMergeEmpty() {
        XCTAssertEqual(TranscriptCleaner.merge([]).count, 0)
    }

    func testMergeSingleSegment() {
        let result = TranscriptCleaner.merge([seg(0, 5, "Hello.")])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Hello.")
    }

    func testMergeShortGap() {
        // Gap = 1 s < 2 s threshold → should merge
        let segments = [seg(0, 2, "Hello"), seg(3, 5, "world")]
        let result = TranscriptCleaner.merge(segments)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Hello world")
    }

    func testMergeLongPause() {
        // Gap = 5 s > 2 s threshold → should split
        let segments = [seg(0, 2, "Hello."), seg(7, 10, "World.")]
        let result = TranscriptCleaner.merge(segments)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].text, "Hello.")
        XCTAssertEqual(result[1].text, "World.")
    }

    func testMergeSpeakerChange() {
        let segments = [seg(0, 2, "Hello", .you), seg(2.5, 5, "Hi there", .others)]
        let result = TranscriptCleaner.merge(segments)
        XCTAssertEqual(result.count, 2)
    }

    func testMergeLongParagraph() {
        // Buffer ≥ 500 chars ending in '.' should trigger a split
        let longText = String(repeating: "x", count: 499) + "."
        let segments = [seg(0, 10, longText), seg(11, 12, "Next.")]
        let result = TranscriptCleaner.merge(segments)
        XCTAssertEqual(result.count, 2, "Long paragraph ending in '.' should split")
    }

    func testMergePreservesTimestamps() {
        let segments = [seg(1, 3, "A"), seg(3.5, 6, "B"), seg(7, 9, "C")]
        let result = TranscriptCleaner.merge(segments)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].startSeconds, 1)
        XCTAssertEqual(result[0].endSeconds, 9)
    }

    func testMergePauseSplitPreservesTimestamps() {
        let segments = [seg(1, 3, "First."), seg(10, 12, "Second.")]
        let result = TranscriptCleaner.merge(segments)
        XCTAssertEqual(result[0].startSeconds, 1)
        XCTAssertEqual(result[0].endSeconds, 3)
        XCTAssertEqual(result[1].startSeconds, 10)
        XCTAssertEqual(result[1].endSeconds, 12)
    }
}
