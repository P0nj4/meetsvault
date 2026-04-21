import Foundation

enum FilenameBuilder {
    static func build(title: String?, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        formatter.locale = Locale.current
        let prefix = formatter.string(from: date)
        let slug = makeSlug(title)
        return "\(prefix)_\(slug)"
    }

    static func uniqueMarkdownURL(base: String, in dir: URL) -> URL {
        var url = dir.appendingPathComponent("\(base).md")
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(base)-\(suffix).md")
            suffix += 1
        }
        return url
    }

    private static func makeSlug(_ title: String?) -> String {
        guard let raw = title, !raw.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "untitled"
        }
        var slug = raw.lowercased()
        slug = slug.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "-")
        while slug.contains("--") { slug = slug.replacingOccurrences(of: "--", with: "-") }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String(slug.prefix(60))
    }
}
