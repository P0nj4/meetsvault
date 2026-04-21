import Foundation

enum TranscriptWriter {
    static func write(
        title: String?,
        startedAt: Date,
        endedAt: Date,
        language: String,
        modelName: String,
        segments: [TranscriptSegment],
        combinedAudioURL: URL
    ) throws -> URL {
        let meetingsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Meetings")
        try FileManager.default.createDirectory(at: meetingsDir, withIntermediateDirectories: true)

        let baseName = FilenameBuilder.build(title: title, date: startedAt)
        let mdURL = FilenameBuilder.uniqueMarkdownURL(base: baseName, in: meetingsDir)
        let wavURL = meetingsDir.appendingPathComponent("\(baseName).wav")

        // Move audio file
        if FileManager.default.fileExists(atPath: wavURL.path) {
            try FileManager.default.removeItem(at: wavURL)
        }
        try FileManager.default.moveItem(at: combinedAudioURL, to: wavURL)

        // Build markdown
        let markdown = buildMarkdown(
            title: title ?? "Untitled",
            startedAt: startedAt,
            endedAt: endedAt,
            language: language,
            modelName: modelName,
            audioFileName: wavURL.lastPathComponent,
            segments: segments
        )
        try markdown.write(to: mdURL, atomically: true, encoding: .utf8)
        return mdURL
    }

    private static func buildMarkdown(
        title: String,
        startedAt: Date,
        endedAt: Date,
        language: String,
        modelName: String,
        audioFileName: String,
        segments: [TranscriptSegment]
    ) -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm:ss"

        let duration = endedAt.timeIntervalSince(startedAt)
        let durationStr = formatDuration(duration)

        var md = """
        ---
        title: \(title)
        date: \(dateFmt.string(from: startedAt))
        started_at: \(timeFmt.string(from: startedAt))
        ended_at: \(timeFmt.string(from: endedAt))
        duration: \(durationStr)
        language: \(language)
        model: whisperkit-\(modelName)
        audio_source: system+microphone
        audio_file: \(audioFileName)
        ---

        # \(title)

        ## Transcript

        """

        for seg in segments {
            let ts = formatTimestamp(seg.startSeconds)
            md += "[\(ts)] \(seg.text)\n"
        }

        md += """

        ## Notes

        <!-- your notes here -->
        """

        return md
    }

    private static func formatTimestamp(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
