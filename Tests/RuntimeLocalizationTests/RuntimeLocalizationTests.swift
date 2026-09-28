import XCTest
@testable import RuntimeLocalization

final class RuntimeLocalizationTests: XCTestCase {

    private func parse(_ key: String, _ value: String) -> [String: String]? {
        let content = "\"\(key)\"=\"\(Localize.escapeForStringsFile(value))\";\n"
        return try? PropertyListSerialization.propertyList(from: Data(content.utf8), format: nil) as? [String: String]
    }

    func testPreEscapedQuotesProduceValidStringsFile() {
        let value = #"accept our <a href=\"https://www.scandlines.com/terms/\">Terms</a>."#
        XCTAssertEqual(parse("k", value)?["k"], #"accept our <a href="https://www.scandlines.com/terms/">Terms</a>."#)
    }

    func testUnescapedQuotesAreEscaped() {
        XCTAssertEqual(parse("k", #"<a href="x">y</a>"#)?["k"], #"<a href="x">y</a>"#)
    }

    func testEscapedNewlineIsPreserved() {
        XCTAssertEqual(parse("k", #"line1\n\nline2"#)?["k"], "line1\n\nline2")
    }

    func testTrailingBackslashDoesNotBreakFile() {
        XCTAssertNotNil(parse("k", #"ends with \"#))
    }
}
