import Foundation
import Testing
@testable import JustSessions

/// Guards against a mistyped color leaving text unreadable. The limits are WCAG contrast ratios.
struct AppThemeReadabilityTests {
    @Test func everyThemeKeepsTextReadableInLightAndDark() {
        for theme in AppTheme.allCases {
            for isDark in [false, true] {
                let colors = theme.colors(isDark: isDark)
                let terminal = colors.terminal
                let variant = "\(theme) \(isDark ? "dark" : "light")"

                #expect(terminal.ansiHexColors.count == 16, "\(variant)")
                // Solarized's light body text is the palest of these, just above 4.
                #expect(contrastRatio(terminal.foreground, colors.contentSurface) >= 4, "\(variant) terminal text")
                #expect(contrastRatio(terminal.selectionForeground, terminal.selectionBackground) >= 3, "\(variant) selection")
                // Bright black carries hints and dim text in many CLIs, so it must not vanish into the background.
                #expect(contrastRatio(terminal.ansiHexColors[8], colors.contentSurface) >= 1.5, "\(variant) bright black")
                #expect(contrastRatio(colors.ink, colors.contentSurface) >= 4.5, "\(variant) ink")
                #expect(contrastRatio(colors.inkForeground, colors.ink) >= 4.5, "\(variant) ink foreground")
            }
        }
    }

    private func contrastRatio(_ first: UInt32, _ second: UInt32) -> Double {
        let luminances = [first, second].map(relativeLuminance).sorted()
        return (luminances[1] + 0.05) / (luminances[0] + 0.05)
    }

    private func relativeLuminance(_ hexValue: UInt32) -> Double {
        let channels = [16, 8, 0].map { shift -> Double in
            let encoded = Double((hexValue >> UInt32(shift)) & 0xFF) / 255
            return encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}
