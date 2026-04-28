import XCTest
@testable import MeetsVault

final class TranscriptDeduplicatorTests: XCTestCase {

    private func seg(_ start: Double, _ end: Double, _ text: String, _ speaker: Speaker = .you) -> TranscriptSegment {
        TranscriptSegment(startSeconds: start, endSeconds: end, text: text, speaker: speaker)
    }

    func testEmptyMic() {
        let system = [seg(0, 2, "Hello there", .others)]
        let result = TranscriptDeduplicator.dedupe(mic: [], system: system)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Hello there")
    }

    func testEmptySystem() {
        let mic = [seg(0, 2, "Hello there", .you)]
        let result = TranscriptDeduplicator.dedupe(mic: mic, system: [])
        XCTAssertEqual(result.count, 1)
    }

    func testBothEmpty() {
        XCTAssertEqual(TranscriptDeduplicator.dedupe(mic: [], system: []).count, 0)
    }

    func testNoTimeOverlapPreserved() {
        let mic = [seg(0, 2, "Hello there friend", .you)]
        let system = [seg(20, 22, "Hello there friend", .others)]
        let result = TranscriptDeduplicator.dedupe(mic: mic, system: system)
        XCTAssertEqual(result.count, 2)
    }

    func testIdenticalTextAndTimeMicDropped() {
        let mic = [seg(0, 2, "Hello there friend, how are you?", .you)]
        let system = [seg(0, 2, "Hello there friend, how are you?", .others)]
        let result = TranscriptDeduplicator.dedupe(mic: mic, system: system)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].speaker, .others)
    }

    func testSmallDelaySameTextMicDropped() {
        let mic = [seg(0.3, 2.3, "Hello there friend, how are you?", .you)]
        let system = [seg(0, 2, "Hello there friend, how are you?", .others)]
        let result = TranscriptDeduplicator.dedupe(mic: mic, system: system)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].speaker, .others)
    }

    func testLargeDelayKept() {
        let mic = [seg(7, 9, "Hello there friend, how are you?", .you)]
        let system = [seg(0, 2, "Hello there friend, how are you?", .others)]
        let result = TranscriptDeduplicator.dedupe(mic: mic, system: system)
        XCTAssertEqual(result.count, 2)
    }

    func testTimeOverlapDifferentTextBothKept() {
        let mic = [seg(0, 2, "Wait I disagree completely", .you)]
        let system = [seg(0, 2, "The proposal sounds great everyone", .others)]
        let result = TranscriptDeduplicator.dedupe(mic: mic, system: system)
        XCTAssertEqual(result.count, 2)
    }

    func testShortCommonPhraseNotIdenticalKept() {
        let mic = [seg(0, 1, "yeah okay", .you)]
        let system = [seg(0, 1, "yeah right", .others)]
        let result = TranscriptDeduplicator.dedupe(mic: mic, system: system)
        XCTAssertEqual(result.count, 2)
    }

    func testShortIdenticalPhraseDropped() {
        let mic = [seg(0, 1, "yeah", .you)]
        let system = [seg(0, 1, "Yeah!", .others)]
        let result = TranscriptDeduplicator.dedupe(mic: mic, system: system)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].speaker, .others)
    }

    func testResultSortedByStart() {
        let mic = [seg(5, 6, "user speaks here briefly", .you)]
        let system = [
            seg(10, 11, "later system says this", .others),
            seg(0, 1, "earlier system says this", .others)
        ]
        let result = TranscriptDeduplicator.dedupe(mic: mic, system: system)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].startSeconds, 0)
        XCTAssertEqual(result[1].startSeconds, 5)
        XCTAssertEqual(result[2].startSeconds, 10)
    }
}
