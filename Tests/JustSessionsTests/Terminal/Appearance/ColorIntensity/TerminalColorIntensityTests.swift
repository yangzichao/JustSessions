import Foundation
import Testing

@testable import JustSessions

/// **Color intensity** scales each ANSI color's OKLab chroma and keeps its lightness and hue, so colored text stays as
/// light or dark against the background as the scheme made it.
struct TerminalColorIntensityTests {
    /// Black, red, green, yellow, blue, magenta, and cyan, normal and bright; white and gray are left out.
    private static let chromaticIndices = [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14]
    private static let softestScheme = AppThemeColors.justSessionsDark.terminal

    private static var everySchemesColors: [UInt32] {
        let themeColors = AppTheme.allCases.flatMap { [$0.colors(isDark: false), $0.colors(isDark: true)] }
        let presetPalettes = TerminalColorPreset.allCases.flatMap { preset -> [TerminalPalette] in
            switch preset.variants {
            case .single(let palette): [palette]
            case .lightAndDark(let light, let dark): [light, dark]
            }
        }
        return themeColors.flatMap(\.terminal.ansiHexColors) + presetPalettes.flatMap(\.scheme.ansiHexColors)
    }

    @Test func oklabGivesBackEverySchemesColorUnchanged() {
        for color in Self.everySchemesColors {
            #expect(OKLabColor(hexValue: color).hexValue == color, "\(String(color, radix: 16))")
        }
    }

    @Test func theDefaultIntensityLeavesEveryColorChoiceAsItIs() {
        let preferences = TerminalAppearancePreferences()
        #expect(preferences.colorIntensityPercent == 100)
        for appTheme in AppTheme.allCases {
            let resolvedTheme = ResolvedAppTheme(appTheme)
            #expect(preferences.colorVariants(appTheme: resolvedTheme) == TerminalPaletteVariants(appTheme: resolvedTheme))
        }
        for preset in TerminalColorPreset.allCases {
            let preferences = TerminalAppearancePreferences(colorChoice: .preset(preset))
            #expect(preferences.colorVariants(appTheme: ResolvedAppTheme(.justSessions)) == preset.variants)
        }
    }

    /// Light colors can't grow much more vivid inside sRGB: bright red and bright blue reach its edge at 1.27 times
    /// their chroma, and stop there.
    @Test func moreIntensityMakesColorsMoreVividAtTheSameLightnessAndHue() {
        for index in Self.chromaticIndices {
            let color = Self.softestScheme.ansiHexColors[index]
            let original = OKLabColor(hexValue: color)
            let adjusted = OKLabColor(hexValue: TerminalColorIntensity.adjusted(color, percent: 150))
            let reachesTheTarget = abs(adjusted.chroma - original.chroma * 1.5) < 0.005
            let reachesTheEdgeOfSRGB = !adjusted.withChroma(adjusted.chroma + 0.01).isInSRGB
            #expect(reachesTheTarget || reachesTheEdgeOfSRGB, "color \(index)")
            #expect(adjusted.chroma > original.chroma * 1.2, "color \(index)")
            Self.expectSameLightnessAndHue(adjusted, original, "color \(index)")
        }
    }

    @Test func lessIntensitySoftensColorsInProportion() {
        for index in Self.chromaticIndices {
            let color = Self.softestScheme.ansiHexColors[index]
            let original = OKLabColor(hexValue: color)
            let adjusted = OKLabColor(hexValue: TerminalColorIntensity.adjusted(color, percent: 50))
            #expect(abs(adjusted.chroma - original.chroma * 0.5) < 0.005, "color \(index)")
            Self.expectSameLightnessAndHue(adjusted, original, "color \(index)")
        }
    }

    /// sRGB's red can't grow more vivid at its lightness, so it stays as it is rather than turning another hue.
    @Test func aColorAsVividAsSRGBShowsStaysAsItIs() {
        let adjusted = TerminalColorIntensity.adjusted(0xFF0000, percent: 200)
        let original = OKLabColor(hexValue: 0xFF0000)
        Self.expectSameLightnessAndHue(OKLabColor(hexValue: adjusted), original, "red")
        #expect(OKLabColor(hexValue: adjusted).chroma > original.chroma - 0.01)
    }

    @Test func graysStayGray() {
        for gray: UInt32 in [0x000000, 0x808080, 0xFFFFFF] {
            for percent in [TerminalColorIntensity.percentRange.lowerBound, TerminalColorIntensity.percentRange.upperBound] {
                #expect(TerminalColorIntensity.adjusted(gray, percent: percent) == gray, "\(String(gray, radix: 16)) at \(percent)%")
            }
        }
    }

    @Test func onlyTheANSIColorsChange() {
        let palette = AppThemeColors.justSessionsDark.terminalPalette
        let adjusted = palette.withANSIColorIntensity(percent: 200)
        #expect(adjusted.background == palette.background)
        #expect(adjusted.scheme.foreground == palette.scheme.foreground)
        #expect(adjusted.scheme.selectionBackground == palette.scheme.selectionBackground)
        #expect(adjusted.scheme.selectionForeground == palette.scheme.selectionForeground)
        #expect(adjusted.scheme.ansiHexColors != palette.scheme.ansiHexColors)
        #expect(adjusted.scheme.ansiHexColors.count == 16)
    }

    private static func expectSameLightnessAndHue(
        _ adjusted: OKLabColor, _ original: OKLabColor, _ comment: Comment, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        // Rounding to 8-bit channels moves both a little, more for a color with little chroma.
        #expect(abs(adjusted.lightness - original.lightness) < 0.01, comment, sourceLocation: sourceLocation)
        let hueDifference = abs(atan2(adjusted.blueYellow, adjusted.greenRed) - atan2(original.blueYellow, original.greenRed))
        #expect(min(hueDifference, 2 * .pi - hueDifference) < 0.06, comment, sourceLocation: sourceLocation)
    }
}
