import Testing

@testable import JustSessions

/// The conversation map's colors keep their contrast on the terminal's own background, which can be dark in a light
/// window (TAB-10): your messages, the CLI's replies, and chips 3:1, letters and captions 4.5:1, and tool runs faint but
/// at least 1.6:1.
struct ConversationMapColorsTests {
    private static func expectReadable(
        _ colors: ConversationMapColors, _ context: String, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let ratio = ThemeColorContrast.ratio
        let background = colors.background
        #expect(ratio(colors.user, background) >= 3, "user, \(context)", sourceLocation: sourceLocation)
        #expect(ratio(colors.reply, background) >= 3, "reply, \(context)", sourceLocation: sourceLocation)
        #expect(ratio(colors.chip, background) >= 3, "chip, \(context)", sourceLocation: sourceLocation)
        // Tool runs stay faint, under your messages and the CLI's replies, but never fade into the background.
        #expect(ratio(colors.tool, background) >= 1.6, "tool, \(context)", sourceLocation: sourceLocation)
        #expect(
            ratio(colors.tool, background) < min(ratio(colors.user, background), ratio(colors.reply, background)),
            "tool fainter, \(context)", sourceLocation: sourceLocation)
        #expect(ratio(colors.chipText, colors.chip) >= 4.5, "chip letter, \(context)", sourceLocation: sourceLocation)
        #expect(ratio(colors.caption, background) >= 4.5, "caption, \(context)", sourceLocation: sourceLocation)
        #expect(colors.user != colors.reply, "user and reply, \(context)", sourceLocation: sourceLocation)
    }

    @Test func marksAndLettersAreReadableInEveryTheme() {
        for theme in AppTheme.allCases {
            for isDark in [false, true] {
                let palette = theme.colors(isDark: isDark).terminalPalette
                for provider in ConversationProvider.allCases {
                    Self.expectReadable(
                        ConversationMapColors(palette: palette, provider: provider), "\(theme) \(isDark ? "dark" : "light") \(provider)")
                }
            }
        }
    }

    @Test func aMidGrayCustomBackgroundStaysReadable() {
        let scheme = TerminalColorScheme(
            foreground: 0x8A8A8A, selectionBackground: 0x606060, selectionForeground: 0xFFFFFF,
            ansiHexColors: Array(repeating: 0x8A8A8A, count: 16))
        let palette = TerminalPalette(background: 0x808080, scheme: scheme)
        for provider in ConversationProvider.allCases {
            Self.expectReadable(ConversationMapColors(palette: palette, provider: provider), "mid gray \(provider)")
        }
    }
}
