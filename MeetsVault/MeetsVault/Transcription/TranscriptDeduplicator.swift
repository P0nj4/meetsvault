import Foundation

enum TranscriptDeduplicator {
    static let delayTolerance: TimeInterval = 1.5
    static let similarityThreshold: Double = 0.6
    static let shortSegmentTokenCount: Int = 3

    static func dedupe(mic: [TranscriptSegment], system: [TranscriptSegment]) -> [TranscriptSegment] {
        let keptMic = mic.filter { m in
            !system.contains { s in isEcho(mic: m, system: s) }
        }
        return (keptMic + system).sorted { $0.startSeconds < $1.startSeconds }
    }

    private static func isEcho(mic m: TranscriptSegment, system s: TranscriptSegment) -> Bool {
        guard m.startSeconds <= s.endSeconds + delayTolerance,
              s.startSeconds <= m.endSeconds + delayTolerance else { return false }

        let mt = tokens(m.text)
        let st = tokens(s.text)
        guard !mt.isEmpty, !st.isEmpty else { return false }

        let sim = jaccard(mt, st)
        if mt.count < shortSegmentTokenCount || st.count < shortSegmentTokenCount {
            return sim >= 1.0
        }
        return sim >= similarityThreshold
    }

    private static func tokens(_ s: String) -> Set<String> {
        let lowered = s.lowercased()
        let stripped = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return Set(String(stripped).split(separator: " ").map(String.init))
    }

    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        let inter = a.intersection(b).count
        let uni = a.union(b).count
        return uni == 0 ? 0 : Double(inter) / Double(uni)
    }
}
