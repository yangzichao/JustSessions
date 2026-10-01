import SwiftUI
import Testing
@testable import JustSessions

struct ThemeColorTests {
    @Test func paletteColorsTakeTheThemeAndAppearanceOfTheirEnvironment() {
        for theme in AppTheme.allCases {
            for colorScheme in [ColorScheme.light, .dark] {
                var environment = EnvironmentValues()
                environment.appTheme = theme
                environment.colorScheme = colorScheme
                let colors = theme.colors(isDark: colorScheme == .dark)
                let expectedHexValues: [(ThemeColor, UInt32)] = [
                    (ThemePalette.sidebarSurface, colors.sidebarSurface),
                    (ThemePalette.contentSurface, colors.contentSurface),
                    (ThemePalette.raisedSurface, colors.raisedSurface),
                    (ThemePalette.userMessageSurface, colors.userMessageSurface),
                    (ThemePalette.ink, colors.ink),
                    (ThemePalette.inkForeground, colors.inkForeground),
                    (ThemePalette.secondaryText, colors.secondaryText),
                    (ThemePalette.hairline, colors.line),
                    (ThemeColor(role: .terminalForeground), colors.terminal.foreground),
                    (ThemeColor(role: .terminalANSI(3)), colors.terminal.ansiHexColors[3]),
                ]
                for (themeColor, expectedHexValue) in expectedHexValues {
                    #expect(hexValue(of: themeColor.resolve(in: environment)) == expectedHexValue, "\(theme) \(colorScheme)")
                }
                #expect(abs(ThemePalette.hairline.resolve(in: environment).opacity - 0.09) < 0.001)
            }
        }
    }

    private func hexValue(of color: Color.Resolved) -> UInt32 {
        [color.red, color.green, color.blue].reduce(0) { hexValue, component in
            hexValue << 8 | UInt32((component * 255).rounded())
        }
    }
}
