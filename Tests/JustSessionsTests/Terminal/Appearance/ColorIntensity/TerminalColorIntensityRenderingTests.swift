import AppKit
import SwiftTerm
import Testing

@testable import JustSessions

/// A SwiftTerm terminal draws the ANSI colors at the chosen **Color intensity**.
@MainActor
struct TerminalColorIntensityRenderingTests {
    private static let hideCursor = "\u{1B}[?25l"
    /// Cells filled with ANSI red, which the terminal draws without adjusting it for contrast.
    private static let redCells = "\u{1B}[41m" + String(repeating: " ", count: 12) + "\u{1B}[0m"

    @Test func ansiColorsAreDrawnAtTheChosenIntensity() throws {
        let themesRed = AppThemeColors.justSessionsDark.terminalPalette.distinguishableANSIHexColors[1]
        let vividRed = AppThemeColors.justSessionsDark.terminalPalette.withANSIColorIntensity(percent: 200)
            .distinguishableANSIHexColors[1]
        try #require(OKLabColor(hexValue: vividRed).chroma > OKLabColor(hexValue: themesRed).chroma + 0.05)

        let colors = try renderedColors(intensityPercent: 200, output: Self.hideCursor + Self.redCells)

        #expect(colors.filter { Self.isClose($0, to: vividRed) }.count > 500)
        #expect(colors.filter { Self.isClose($0, to: themesRed) }.isEmpty)
    }

    private func renderedColors(intensityPercent: Int, output: String) throws -> [UInt32] {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        TerminalAppearancePreferences(mode: .dark, colorIntensityPercent: intensityPercent).save(to: settings.userDefaults)
        let terminalView = SelectableTerminalView(
            frame: NSRect(x: 0, y: 0, width: 400, height: 120),
            appearanceStore: TerminalAppearanceStore(userDefaults: settings.userDefaults),
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
