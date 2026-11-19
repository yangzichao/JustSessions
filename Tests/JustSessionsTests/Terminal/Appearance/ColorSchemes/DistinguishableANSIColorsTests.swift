import Testing

@testable import JustSessions

struct DistinguishableANSIColorsTests {
    @Test func everyPresetsANSIColorsStandApartFromItsBackground() {
        for preset in TerminalColorPreset.allCases {
            let palettes: [TerminalPalette] =
                switch preset.variants {
                case .single(let palette): [palette]
                case .lightAndDark(let light, let dark): [light, dark]
                }
            for palette in palettes {
                for (index, color) in palette.distinguishableANSIHexColors.enumerated() {
                    let ratio = ThemeColorContrast.ratio(color, palette.background)
                    #expect(
                        ratio >= TerminalPalette.minimumANSIFillRatio,
                        "\(preset) on \(String(palette.background, radix: 16)) ANSI \(index): \(ratio)")
                }
            }
        }
    }

    @Test func atomOneDarksBlackIsLightenedOffTheBackground() {
        let palette = AppThemeColors.atomOneDark.terminalPalette
        #expect(palette.scheme.ansiHexColors[0] == palette.background)

        let black = palette.distinguishableANSIHexColors[0]
        #expect(ThemeColorContrast.ratio(black, palette.background) >= TerminalPalette.minimumANSIFillRatio)
        #expect(ThemeColorContrast.ratio(black, 0xFFFFFF) < ThemeColorContrast.ratio(palette.background, 0xFFFFFF))
    }

    @Test func atomOneLightsWhitesAreDarkenedOffTheBackground() {
        let palette = AppThemeColors.atomOneLight.terminalPalette
        let colors = palette.distinguishableANSIHexColors
        for index in [7, 15] {
            #expect(ThemeColorContrast.ratio(colors[index], palette.background) >= TerminalPalette.minimumANSIFillRatio)
            #expect(ThemeColorContrast.ratio(colors[index], 0x000000) < ThemeColorContrast.ratio(palette.background, 0x000000))
        }
    }

    @Test func colorsAlreadyApartFromTheBackgroundKeepTheSchemesOwnValues() {
        let atomOneDark = AppThemeColors.atomOneDark.terminalPalette
        #expect(Array(atomOneDark.distinguishableANSIHexColors.dropFirst()) == Array(atomOneDark.scheme.ansiHexColors.dropFirst()))
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
        #expect(
            ThemeColorContrast.ratio(palette.distinguishableANSIHexColors[0], palette.background) >= TerminalPalette.minimumANSIFillRatio)
    }
}
