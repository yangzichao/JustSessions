import Testing
@testable import JustSessions

/// Guards against a mistyped preset color leaving terminal text unreadable. The limits are WCAG contrast ratios.
struct TerminalColorPresetReadabilityTests {
    @Test func everyPresetKeepsTextReadableInEachVersion() {
        for preset in TerminalColorPreset.allCases {
            let palettes: [TerminalPalette] = switch preset.variants {
            case .single(let palette): [palette]
            case .lightAndDark(let light, let dark): [light, dark]
            }
            for palette in palettes {
                let scheme = palette.scheme
                let variant = "\(preset) on \(String(palette.background, radix: 16))"
                #expect(scheme.ansiHexColors.count == 16, "\(variant)")
                #expect(ThemeColorContrast.ratio(scheme.foreground, palette.background) >= 4, "\(variant) text")
                #expect(ThemeColorContrast.ratio(scheme.readableSelectionForeground, scheme.selectionBackground) >= 4.5, "\(variant) selection")
                // Bright black carries hints and dim text in many CLIs, so it must not vanish into the background.
                #expect(ThemeColorContrast.ratio(scheme.ansiHexColors[8], palette.background) >= 1.5, "\(variant) bright black")
            }
        }
    }

    @Test func selectedTextIsMadeReadableWhenImportedColorsBarelyDiffer() {
        let scheme = TerminalColorScheme(
            foreground: 0x333333, selectionBackground: 0x9AA5CE, selectionForeground: 0x7A85AE,
            ansiHexColors: Array(repeating: 0x333333, count: 16)
        )
        #expect(ThemeColorContrast.ratio(scheme.selectionForeground, scheme.selectionBackground) < 1.5)
        #expect(ThemeColorContrast.ratio(scheme.readableSelectionForeground, scheme.selectionBackground) >= 4.5)
    }

    @Test func selectedTextKeepsAReadableSchemesOwnColor() {
        let scheme = AppThemeColors.gitHubLight.terminal
        #expect(scheme.readableSelectionForeground == scheme.selectionForeground)
    }

    @Test func lightAndDarkVersionsAreLightAndDark() {
        for preset in TerminalColorPreset.allCases {
            switch preset.variants {
            case .single(let palette):
                #expect(palette.isDark, "\(preset) has only a dark version")
            case .lightAndDark(let light, let dark):
                #expect(!light.isDark, "\(preset) light")
                #expect(dark.isDark, "\(preset) dark")
            }
        }
    }

    @Test func appThemePresetsUseTheirThemesTerminalColors() {
        #expect(TerminalColorPreset.gruvbox.variants.palette(usesDarkColors: true) == AppThemeColors.gruvboxDark.terminalPalette)
        #expect(TerminalColorPreset.justSessions.variants.palette(usesDarkColors: false) == AppThemeColors.justSessionsLight.terminalPalette)
        #expect(TerminalColorPreset.gruvbox.displayName == AppTheme.gruvbox.displayName)
    }
}
