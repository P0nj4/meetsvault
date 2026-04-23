import XCTest
@testable import MeetsVault

final class LanguageCodeTests: XCTestCase {

    func testTopIsSubsetOfAll() {
        let allCodes = Set(LanguageCode.all.map(\.code))
        for lang in LanguageCode.top {
            XCTAssertTrue(allCodes.contains(lang.code), "\(lang.code) in top but not in all")
        }
    }

    func testAllCodesUnique() {
        let codes = LanguageCode.all.map(\.code)
        XCTAssertEqual(codes.count, Set(codes).count, "Duplicate codes found in LanguageCode.all")
    }

    func testDisplayNamesNonEmpty() {
        for lang in LanguageCode.all {
            XCTAssertFalse(lang.displayName.isEmpty, "Empty displayName for code '\(lang.code)'")
        }
    }

    func testIdEqualsCode() {
        for lang in LanguageCode.all {
            XCTAssertEqual(lang.id, lang.code)
        }
    }

    func testEnglishIsFirst() {
        XCTAssertEqual(LanguageCode.top.first?.code, "en")
        XCTAssertEqual(LanguageCode.top.first?.displayName, "English")
    }
}
