import Testing
@testable import JustSessions

/// A fill in any ANSI color can be seen, such as Claude Code's selection when it is held to 16 colors.
struct DistinguishableANSIColorsTests {
    @Test func everyPresetsANSIColorsStandApartFromItsBackground() {
        for preset in TerminalColorPreset.allCases {
            let palettes: [TerminalPalette] = switch preset.variants {
            case .single(let palette): [palette]
            case .lightAndDark(let light, let dark): [light, dark]
            }
            for palette in palettes {
                for (index, color) in palette.distinguishableANSIHexColors.enumerated() {
                    let ratio = ThemeColorContrast.ratio(color, palette.background)
                    #expect(ratio >= TerminalPalette.minimumANSIFillRatio, "\(preset) on \(String(palette.background, radix: 16)) ANSI \(index): \(ratio)")
                }
            }
        }
    }

    /// Atom One Dark's black is its background, `0x282C34`, so a selection filled with black vanished.
    @Test func atomOneDarksBlackIsLightenedOffTheBackground() {
        let palette = AppThemeColors.atomOneDark.terminalPalette
        #expect(palette.scheme.ansiHexColors[0] == palette.background)

        let black = palette.distinguishableANSIHexColors[0]
        #expect(ThemeColorContrast.ratio(black, palette.background) >= TerminalPalette.minimumANSIFillRatio)
        // Lighter: nearer to white than the background is.
        #expect(ThemeColorContrast.ratio(black, 0xFFFFFF) < ThemeColorContrast.ratio(palette.background, 0xFFFFFF))
    }

    /// Atom One Light's white is its background, `0xFAFAFA`, and its bright white `0xFFFFFF` is barely apart from it.
    @Test func atomOneLightsWhitesAreDarkenedOffTheBackground() {
        let palette = AppThemeColors.atomOneLight.terminalPalette
        let colors = palette.distinguishableANSIHexColors
        for index in [7, 15] {
            #expect(ThemeColorContrast.ratio(colors[index], palette.background) >= TerminalPalette.minimumANSIFillRatio)
            // Darker: nearer to black than the background is.
            #expect(ThemeColorContrast.ratio(colors[index], 0x000000) < ThemeColorContrast.ratio(palette.background, 0x000000))
        }
    }

    @Test func colorsAlreadyApartFromTheBackgroundKeepTheSchemesOwnValues() {
        let atomOneDark = AppThemeColors.atomOneDark.terminalPalette
        #expect(Array(atomOneDark.distinguishableANSIHexColors.dropFirst()) == Array(atomOneDark.scheme.ansiHexColors.dropFirst()))
        // Nord's black is 1.24 from its background.
        let nord = TerminalColorPreset.nord.variants.palette(usesDarkColors: true)
        #expect(nord.distinguishableANSIHexColors == nord.scheme.ansiHexColors)
    }

    @Test func anImportedBlackThatIsTheBackgroundIsMovedOffIt() {
        let palette = TerminalPalette(
            background: 0x101010,
            scheme: TerminalColorScheme(
                foreground: 0xEEEEEE, selectionBackground: 0x444444, selectionForeground: 0xEEEEEE,
                ansiHexColors: [0x101010] + Array(repeating: 0xCC6666, count: 15)
            )
        )
        #expect(ThemeColorContrast.ratio(palette.distinguishableANSIHexColors[0], palette.background) >= TerminalPalette.minimumANSIFillRatio)
    }
}
