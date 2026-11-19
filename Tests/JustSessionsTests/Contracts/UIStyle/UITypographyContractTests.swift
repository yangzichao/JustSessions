import Foundation
import Testing

struct UITypographyContractTests {
    @Test func viewsNameNoFontSizeOfTheirOwn() throws {
        let literalSize = try Regex(#"\.system\(size: *[0-9]"#)
        let offendingLines = try ViewSourceLines().lines(matching: literalSize)
        #expect(offendingLines.isEmpty, "Use ThemeFont or ThemeFont.glyph:\n\(offendingLines.joined(separator: "\n"))")
    }

    @Test func viewsUseTheTypeScaleInPlaceOfSystemTextStyles() throws {
        let systemTextStyle = try Regex(
            #"(\.font\(|\.system\(|font = )\.(largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption|caption2)\b"#
        )
        let offendingLines = try ViewSourceLines().lines(matching: systemTextStyle)
        #expect(offendingLines.isEmpty, "Use ThemeFont:\n\(offendingLines.joined(separator: "\n"))")
    }
}
