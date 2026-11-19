import Foundation
import Testing

struct UIColorContractTests {
    @Test func viewsDrawInTheThemesColors() throws {
        let systemColor = try Regex(
            #"(foregroundStyle|foregroundColor|fill|stroke|strokeBorder|background|tint)\([^)]*\.(primary|secondary|tertiary|quaternary|red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown|gray|white|black|accentColor)\b"#
        )
        let offendingLines = try ViewSourceLines().lines(matching: systemColor)
        #expect(offendingLines.isEmpty, "Use ThemePalette's colors:\n\(offendingLines.joined(separator: "\n"))")
    }
}
