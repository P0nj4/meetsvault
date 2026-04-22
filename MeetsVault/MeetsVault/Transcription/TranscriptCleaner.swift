import Foundation

enum TranscriptCleaner {
    private static let pauseThreshold: TimeInterval = 2.0
    private static let maxParagraphChars: Int = 500

    private static let tokenRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: "<\\|[^|]*\\|>")
    }()

    static func stripTokens(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = tokenRegex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return cleaned
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func merge(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        guard !segments.isEmpty else { return [] }

        var result: [TranscriptSegment] = []
        var groupStart = segments[0].startSeconds
        var groupEnd = segments[0].endSeconds
        var groupSpeaker = segments[0].speaker
        var buffer = segments[0].text
        var previousEnd = segments[0].endSeconds

        for seg in segments.dropFirst() {
            let gap = seg.startSeconds - previousEnd
            let longPause = gap > pauseThreshold
            let longParagraph = buffer.count >= maxParagraphChars && endsSentence(buffer)
            let speakerChange = seg.speaker != groupSpeaker

            if longPause || longParagraph || speakerChange {
                result.append(TranscriptSegment(
                    startSeconds: groupStart,
                    endSeconds: groupEnd,
                    text: buffer,
                    speaker: groupSpeaker
                ))
                groupStart = seg.startSeconds
                groupSpeaker = seg.speaker
                buffer = seg.text
            } else {
                buffer = buffer.isEmpty ? seg.text : buffer + " " + seg.text
            }
            groupEnd = seg.endSeconds
            previousEnd = seg.endSeconds
        }

        result.append(TranscriptSegment(
            startSeconds: groupStart,
            endSeconds: groupEnd,
            text: buffer,
            speaker: groupSpeaker
        ))
        return result
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
        return ".!?".contains(last)
    }
}
