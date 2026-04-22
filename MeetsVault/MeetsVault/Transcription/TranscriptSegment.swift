import Foundation

enum Speaker: String {
    case you
    case others
}

struct TranscriptSegment {
    let startSeconds: Double
    let endSeconds: Double
    let text: String
    let speaker: Speaker
}
