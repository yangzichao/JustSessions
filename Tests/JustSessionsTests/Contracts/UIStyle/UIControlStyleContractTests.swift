import Foundation
import Testing

struct UIControlStyleContractTests {
    @Test func viewsUseTheThemesButtonAndFieldStyles() throws {
        let systemStyle = try Regex(
            #"\.(buttonStyle|toggleStyle|textFieldStyle)\(\.(automatic|bordered|borderedProminent|borderless|plain|link|accessoryBar|accessoryBarAction|switch|checkbox|button|roundedBorder|squareBorder)\b"#
        )
        let plainFieldInSearchField = try Regex(#"\.textFieldStyle\(\.plain\)"#)
        let offendingLines = try ViewSourceLines().lines(matching: systemStyle).filter { line in
            !((line.contains("Search") || line.contains("Find")) && line.contains(plainFieldInSearchField))
        }
        #expect(offendingLines.isEmpty, "Use the theme's styles in Views/Theme:\n\(offendingLines.joined(separator: "\n"))")
    }

    @Test func viewsUseTheThemesSegmentedPicker() throws {
        let systemSegmentedPicker = try Regex(#"\.pickerStyle\(\.segmented\)"#)
        let offendingLines = try ViewSourceLines().lines(matching: systemSegmentedPicker)
        #expect(offendingLines.isEmpty, "Use ThemeSegmentedPicker:\n\(offendingLines.joined(separator: "\n"))")
    }

    @Test func disclosureGroupTitlesOpenTheGroup() throws {
        let disclosureGroup = try Regex(#"\bDisclosureGroup\("#)
        let offendingFiles = try ViewSourceLines().files
            .filter { file in
                file.lines.contains { $0.contains(disclosureGroup) }
                    && !file.lines.contains { $0.contains("ThemeDisclosureTitleButton") }
            }
            .map(\.path)
        #expect(offendingFiles.isEmpty, "Use ThemeDisclosureTitleButton as the title:\n\(offendingFiles.joined(separator: "\n"))")
    }

    @Test func dividersBetweenViewsAreTheThemes() throws {
        let source = try ViewSourceLines()
        let menuBuilder = try Regex(#"Menu|menu|Commands|Picker"#)
        let systemDivider = try Regex(#"\bDivider\(\)"#)
        let offendingFiles = source.files
            .filter { file in
                file.lines.contains { $0.contains(systemDivider) } && !file.lines.contains { $0.contains(menuBuilder) }
            }
            .map(\.path)
        #expect(offendingFiles.isEmpty, "Use ThemeDivider:\n\(offendingFiles.joined(separator: "\n"))")
    }
}
