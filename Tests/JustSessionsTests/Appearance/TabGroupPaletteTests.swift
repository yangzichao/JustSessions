import SwiftUI
import Testing
@testable import JustSessions

struct TabGroupPaletteTests {
    @Test func existingProjectColorsChangeWithTheThemeAndAppearance() {
        let projectKeys = (0..<8).map { "/tmp/project-\($0)" }
        // Keep these same styles alive, as the tab bar does while its terminals stay open.
        let projectColors = TabGroupPalette.colorsByProjectKey(projectKeys)
        var resolvedPalettes: Set<[UInt32]> = []
        for theme in AppTheme.allCases {
            for colorScheme in [ColorScheme.light, .dark] {
                var environment = EnvironmentValues()
                environment.appTheme = ResolvedAppTheme(theme)
                environment.colorScheme = colorScheme
                let palette = projectKeys.compactMap { projectColors[$0] }.map {
                    hexValue(of: $0.resolve(in: environment))
                }
                #expect(palette.count == projectKeys.count)
                #expect(Set(palette).count == projectKeys.count, "Distinct groups in \(theme) \(colorScheme)")
                #expect(resolvedPalettes.insert(palette).inserted, "Theme switch changes \(theme) \(colorScheme)")
                let assignedIndices = TabGroupColorAssignment.colorIndices(forProjectKeys: projectKeys, paletteSize: 8)
                let expectedColors = theme.colors(isDark: colorScheme == .dark).tabGroupHexColors
                #expect(palette == assignedIndices.map { expectedColors[$0] })
            }
        }
    }

    private func hexValue(of color: Color.Resolved) -> UInt32 {
        [color.red, color.green, color.blue].reduce(0) { result, component in
            result << 8 | UInt32((component * 255).rounded())
        }
    }
}
