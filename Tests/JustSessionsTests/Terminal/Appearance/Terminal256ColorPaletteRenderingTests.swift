import AppKit
import SwiftTerm
import Testing

@testable import JustSessions

/// Claude Code draws most of its colored text in colors 16–255 of the 256-color palette. These render a terminal to
/// check that those colors are xterm's in every theme, as Ghostty draws them, rather than blended from the theme's
/// 16 ANSI colors, which drained them on themes with soft ANSI colors such as JustSessions's dark version.
@MainActor
struct Terminal256ColorPaletteRenderingTests {
    private static let hideCursor = "\u{1B}[?25l"
    /// Colors Claude Code 2.1.296 drew with in tmux, from the cube and from the gray ramp, with xterm's values.
    private static let xtermColors: [(index: Int, color: UInt32)] = [(105, 0x8787FF), (71, 0x5FAF5F), (241, 0x626262)]

    @Test(arguments: [false, true])
    func extendedColorsAreXtermsWhateverTheTheme(isDark: Bool) throws {
        for (index, xtermColor) in Self.xtermColors {
            // A fill, which the terminal draws in the palette's color without adjusting it for contrast.
            let filledCells = "\u{1B}[48;5;\(index)m" + String(repeating: " ", count: 12) + "\u{1B}[0m"
            let colors = try renderedColors(isDark: isDark, output: Self.hideCursor + filledCells)
            let matchingPixelCount = colors.filter { Self.isClose($0, to: xtermColor) }.count
            #expect(matchingPixelCount > 500, "color \(index), dark: \(isDark)")
        }
    }

    private func renderedColors(isDark: Bool, output: String) throws -> [UInt32] {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        store.setMode(isDark ? .dark : .light)
        let terminalView = SelectableTerminalView(
            frame: NSRect(x: 0, y: 0, width: 400, height: 120),
            appearanceStore: store,
            themeStore: AppThemeStore(userDefaults: settings.userDefaults)
        )
        terminalView.feed(text: output)
        let representation = try #require(terminalView.snapshotOverLayerBackground())
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
