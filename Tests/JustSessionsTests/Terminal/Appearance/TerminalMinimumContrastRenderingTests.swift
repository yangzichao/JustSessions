import AppKit
import SwiftTerm
import Testing
@testable import JustSessions

/// A CLI picks its colors for a light or a dark background and keeps them after the theme changes. These render a
/// terminal to check that such text is drawn readable while block characters, which draw shapes, keep their color.
@MainActor
struct TerminalMinimumContrastRenderingTests {
    private static let hideCursor = "\u{1B}[?25l"
    /// Near-white, as Claude Code's dark theme draws code: almost invisible on a light theme as sent.
    private static let nearWhiteText = "\u{1B}[1;38;2;250;250;250mMMMM\u{1B}[0m"
    /// Pale lavender block elements, as a CLI draws pixel art meant to blend into the background.
    private static let paleBlocks = "\u{1B}[38;2;225;225;250m\u{2588}\u{2588}\u{2588}\u{2588}\u{1B}[0m"

    @Test func textColoredForADarkBackgroundIsDrawnReadableOnALightTheme() throws {
        let colors = try renderedColors(isDark: false, output: Self.hideCursor + Self.nearWhiteText)
        let background = AppThemeColors.justSessionsLight.contentSurface
        let mostContrast = colors.map { ThemeColorContrast.ratio($0, background) }.max() ?? 0
        // Antialiasing softens glyph edges, but the strokes' cores are drawn in the adjusted color.
        #expect(mostContrast >= 4.4)
        #expect(mostContrast < 6, "The text should darken only as far as the minimum, not to black")
    }

    @Test func textColoredForALightBackgroundIsDrawnReadableOnADarkTheme() throws {
        let nearBlackText = "\u{1B}[1;38;2;40;40;48mMMMM\u{1B}[0m"
        let colors = try renderedColors(isDark: true, output: Self.hideCursor + nearBlackText)
        let background = AppThemeColors.justSessionsDark.contentSurface
        let mostContrast = colors.map { ThemeColorContrast.ratio($0, background) }.max() ?? 0
        #expect(mostContrast >= 4.4)
    }

    @Test func blockElementsKeepTheColorTheProgramChose() throws {
        let colors = try renderedColors(isDark: false, output: Self.hideCursor + Self.paleBlocks)
        let paleLavenderPixelCount = colors.filter { Self.isClose($0, to: 0xE1E1FA) }.count
        #expect(paleLavenderPixelCount > 500)
    }

    private func renderedColors(isDark: Bool, output: String) throws -> [UInt32] {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        store.setMode(isDark ? .dark : .light)
        store.setFontSize(TerminalAppearancePreferences.fontSizeRange.upperBound)
        let terminalView = SelectableTerminalView(
            frame: NSRect(x: 0, y: 0, width: 400, height: 120),
            appearanceStore: store,
            themeStore: AppThemeStore(userDefaults: settings.userDefaults)
        )
        terminalView.feed(text: output)
        let representation = try #require(terminalView.bitmapImageRepForCachingDisplay(in: terminalView.bounds))
        terminalView.cacheDisplay(in: terminalView.bounds, to: representation)
        var colors: [UInt32] = []
        for y in 0..<representation.pixelsHigh {
            for x in 0..<representation.pixelsWide {
                guard let color = representation.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let channels = [color.redComponent, color.greenComponent, color.blueComponent]
                colors.append(channels.reduce(0) { $0 << 8 | UInt32(($1 * 255).rounded()) })
            }
        }
        return colors
    }

    private static func isClose(_ color: UInt32, to expected: UInt32) -> Bool {
        [16, 8, 0].allSatisfy { shift in
            abs(Int((color >> UInt32(shift)) & 0xFF) - Int((expected >> UInt32(shift)) & 0xFF)) <= 3
        }
    }
}
