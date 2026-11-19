import Foundation
import Testing

/// Every sheet lays out its title, content, and buttons with `ThemeSheetLayout`, so sheets share their title size,
/// margins, and footer. Settings is the exception: its pages switch under a tab picker and share one size.
struct UISheetContractTests {
    @Test func sheetsUseTheSharedLayout() throws {
        let sheetFiles = try ViewSourceLines().files.filter { file in
            file.path.hasSuffix("Sheet.swift") && file.lines.contains { $0.contains(": View {") }
        }
        let offendingFiles =
            sheetFiles
            .filter { !$0.path.hasSuffix("Settings/SettingsSheet.swift") }
            .filter { file in !file.lines.contains { $0.contains("ThemeSheetLayout(") } }
            .map(\.path)
        #expect(!sheetFiles.isEmpty)
        #expect(offendingFiles.isEmpty, "Lay these sheets out with ThemeSheetLayout:\n\(offendingFiles.joined(separator: "\n"))")
    }

    /// Buttons in a sheet are quiet unless they say otherwise, so its default action names the prominent style it takes.
    @Test func aSheetsDefaultActionIsProminent() throws {
        let sheetFiles = try ViewSourceLines().files.filter { $0.path.hasSuffix("Sheet.swift") }
        let prominentStyle = try Regex(#"\.buttonStyle\((Theme|Provider)ProminentButtonStyle\("#)
        var offendingLines: [String] = []
        for file in sheetFiles {
            for (index, line) in file.lines.enumerated() where line.contains(".keyboardShortcut(.defaultAction)") {
                // The style is set on the same button, on one of the few lines before its shortcut.
                let button = file.lines[max(index - 3, 0)...index]
                if !button.contains(where: { $0.contains(prominentStyle) }) {
                    offendingLines.append("Views/\(file.path):\(index + 1)")
                }
            }
        }
        #expect(offendingLines.isEmpty, "Give the default action a prominent style:\n\(offendingLines.joined(separator: "\n"))")
    }
}
