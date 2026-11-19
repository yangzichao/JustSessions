import Foundation
import Testing

struct UICornerRadiusContractTests {
    @Test func viewsNameNoCornerRadiusOfTheirOwn() throws {
        let literalRadius = try Regex(#"[cC]ornerRadius[A-Za-z]*(: CGFloat)? *[:=] *[0-9]"#)
        let offendingLines = try ViewSourceLines().lines(matching: literalRadius)
        #expect(offendingLines.isEmpty, "Use ThemeCornerRadius:\n\(offendingLines.joined(separator: "\n"))")
    }
}
