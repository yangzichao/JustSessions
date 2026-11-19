import Foundation
import Testing

struct UIShadowAndMotionContractTests {
    @Test func viewsCastTheThemesShadows() throws {
        let systemShadow = try Regex(#"\.shadow\("#)
        let offendingLines = try ViewSourceLines().lines(matching: systemShadow)
        #expect(offendingLines.isEmpty, "Use themeShadow(_:):\n\(offendingLines.joined(separator: "\n"))")
    }

    @Test func viewsAnimateAtTheThemesPace() throws {
        let literalDuration = try Regex(#"\.(easeOut|easeIn|easeInOut|linear|spring|smooth|snappy|bouncy)\(duration: *[0-9]"#)
        let offendingLines = try ViewSourceLines().lines(matching: literalDuration)
        #expect(offendingLines.isEmpty, "Use ThemeMotion:\n\(offendingLines.joined(separator: "\n"))")
    }
}
