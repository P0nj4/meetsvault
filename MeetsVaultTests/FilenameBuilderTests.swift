import XCTest
@testable import MeetsVault

final class FilenameBuilderTests: XCTestCase {
    private let fixedDate: Date = {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 3; comps.day = 15
        comps.hour = 9; comps.minute = 5
        return Calendar.current.date(from: comps)!
    }()

    func testBuildContainsDatePrefix() {
        let result = FilenameBuilder.build(title: "Test", date: fixedDate)
        XCTAssertTrue(result.hasPrefix("2024-03-15_0905"), "Expected date prefix, got: \(result)")
    }

    func testNilTitleProducesUntitled() {
        let result = FilenameBuilder.build(title: nil, date: fixedDate)
        XCTAssertTrue(result.hasSuffix("_untitled"), "Expected '_untitled' suffix, got: \(result)")
    }

    func testBlankTitleProducesUntitled() {
        let result = FilenameBuilder.build(title: "   ", date: fixedDate)
        XCTAssertTrue(result.hasSuffix("_untitled"), "Expected '_untitled' suffix, got: \(result)")
    }

    func testSlugLowercases() {
        let result = FilenameBuilder.build(title: "Hello World", date: fixedDate)
        XCTAssertTrue(result.hasSuffix("_hello-world"), result)
    }

    func testSlugSpecialChars() {
        let result = FilenameBuilder.build(title: "Q&A: Let's go!", date: fixedDate)
        let slug = result.components(separatedBy: "_").last!
        XCTAssertFalse(slug.contains("&"), slug)
        XCTAssertFalse(slug.contains(":"), slug)
        XCTAssertFalse(slug.contains("!"), slug)
        XCTAssertFalse(slug.contains("--"), "Consecutive dashes should collapse: \(slug)")
    }

    func testSlugCollapsesDashes() {
        let result = FilenameBuilder.build(title: "a   b", date: fixedDate)
        XCTAssertTrue(result.hasSuffix("_a-b"), result)
    }

    func testSlugTruncatesAt60() {
        let longTitle = String(repeating: "a", count: 80)
        let result = FilenameBuilder.build(title: longTitle, date: fixedDate)
        let slug = result.components(separatedBy: "_").last!
        XCTAssertLessThanOrEqual(slug.count, 60, "Slug should be capped at 60 chars")
    }

    func testUniqueURLNoConflict() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let url = FilenameBuilder.uniqueMarkdownURL(base: "meeting", in: tmp)
        XCTAssertEqual(url.lastPathComponent, "meeting.md")
    }

    func testUniqueURLConflict() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let base = tmp.appendingPathComponent("meeting.md")
        FileManager.default.createFile(atPath: base.path, contents: nil)

        let url = FilenameBuilder.uniqueMarkdownURL(base: "meeting", in: tmp)
        XCTAssertEqual(url.lastPathComponent, "meeting-2.md")
    }
}
