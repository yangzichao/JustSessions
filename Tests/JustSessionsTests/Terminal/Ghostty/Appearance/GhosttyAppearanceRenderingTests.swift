import AppKit
import GhosttyTerminal
import Testing
@testable import JustSessions

/// Ghostty terminals drawn with a controller from `GhosttyTerminalControllers`, read back from the view's snapshot.
@MainActor
@Suite(.serialized)
struct GhosttyAppearanceRenderingTests {
    private static let hideCursor = "\u{1B}[?25l"
    /// Full blocks fill their cells, so their color is drawn without antialiasing.
    private static let blocks = String(repeating: "\u{2588}", count: 4)

    @Test func theBackgroundAndTheColorsProgramsChooseAreDrawnAsConfigured() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        let light = AppThemeColors.justSessionsLight.terminalPalette

        terminal.show(Self.hideCursor + "\u{1B}[31m" + Self.blocks + "\u{1B}[38;2;18;52;86m" + Self.blocks + "\u{1B}[0m")

        try await expectEventually {
            let colors = terminal.drawnColors()
            return colors.covers(light.background, pixels: 10_000)
                && colors.covers(light.scheme.ansiHexColors[1], pixels: 1_000)
                && colors.covers(0x123456, pixels: 1_000)
        }
    }

    /// As in SwiftTerm, bold text in one of the first ANSI colors is drawn in its bright version.
    @Test func boldTextInTheFirstANSIColorsIsDrawnBright() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)

        terminal.show(Self.hideCursor + "\u{1B}[1;31m" + Self.blocks + "\u{1B}[0m")

        try await expectEventually {
            terminal.drawnColors().covers(AppThemeColors.justSessionsLight.terminal.ansiHexColors[9], pixels: 1_000)
        }
    }

    @Test func aDarkTerminalViewDrawsTheDarkVersion() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        terminal.show(Self.hideCursor)
        try await expectEventually { terminal.drawnColors().covers(AppThemeColors.justSessionsLight.contentSurface, pixels: 10_000) }

        terminal.view.appearance = NSAppearance(named: .darkAqua)

        try await expectEventually { terminal.drawnColors().covers(AppThemeColors.justSessionsDark.contentSurface, pixels: 10_000) }
    }

    @Test func choosingAThemeRedrawsOpenTerminals() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        terminal.show(Self.hideCursor)
        try await expectEventually { terminal.drawnColors().covers(AppThemeColors.justSessionsLight.contentSurface, pixels: 10_000) }

        stores.theme.setTheme(.gruvbox)

        try await expectEventually { terminal.drawnColors().covers(AppThemeColors.gruvboxLight.contentSurface, pixels: 10_000) }
    }

    /// Ghostty, unlike SwiftTerm, turns such text black or white rather than darkening it only as far as the minimum.
    @Test func textColoredForADarkBackgroundIsDrawnReadableOnALightTheme() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        let background = AppThemeColors.justSessionsLight.contentSurface

        terminal.show(Self.hideCursor + "\u{1B}[1;38;2;250;250;250mMMMM\u{1B}[0m")

        try await expectEventually {
            // Before its first frame the snapshot is black, which would pass for readable text.
            let colors = terminal.drawnColors()
            let mostContrast = colors.keys.map { ThemeColorContrast.ratio($0, background) }.max() ?? 0
            return colors.covers(background, pixels: 10_000) && mostContrast >= 4.5
        }
    }

    @Test func blockElementsKeepTheColorTheProgramChose() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)

        terminal.show(Self.hideCursor + "\u{1B}[38;2;225;225;250m" + Self.blocks + "\u{1B}[0m")

        try await expectEventually { terminal.drawnColors().covers(0xE1E1FA, pixels: 1_000) }
    }

    /// Select All from the Edit menu runs Ghostty's action directly, so it works with Ghostty's shortcuts cleared.
    @Test func selectAllDrawsTheSelectionInTheThemesColors() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        let scheme = AppThemeColors.justSessionsLight.terminal
        // The two blocks show the selection's text color, and the six spaces after them, three times the area, its
        // background.
        terminal.show(Self.hideCursor + "\u{2588}\u{2588}      .")

        terminal.view.selectAll(nil)

        try await expectEventually {
            let colors = terminal.drawnColors()
            return colors.covers(scheme.selectionBackground, pixels: 2_500) && colors.covers(scheme.readableSelectionForeground, pixels: 800)
        }
    }

    /// Tokyo Night Day's own selection colors are 3.3 apart, so its selected text is drawn in the readable color, as
    /// in SwiftTerm; see `TerminalMinimumContrastRenderingTests`.
    @Test func selectedTextIsDrawnReadableOnTheSelection() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        stores.theme.setTheme(.tokyoNight)
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        let scheme = AppThemeColors.tokyoNightDay.terminal
        terminal.show(Self.hideCursor + "\u{2588}\u{2588}      .")

        terminal.view.selectAll(nil)

        try await expectEventually(timeout: .seconds(30)) {
            let colors = terminal.drawnColors()
            return colors.covers(scheme.selectionBackground, pixels: 2_500) && colors.covers(scheme.readableSelectionForeground, pixels: 800)
        }
    }

    /// The system font has no Nerd Font icons, so Ghostty draws them with its built-in Symbols Nerd Font.
    @Test func nerdFontIconsAreDrawn() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let controller = stores.controller()
        let foreground = AppThemeColors.justSessionsLight.terminal.foreground
        let missing = GhosttyTestTerminal(controller: controller, appearance: .aqua)
        // A private-use character no font has, which Ghostty draws as a small placeholder.
        missing.show(Self.hideCursor + "\u{10FFFD}")
        let icon = GhosttyTestTerminal(controller: controller, appearance: .aqua)
        // Nerd Fonts' house icon.
        icon.show(Self.hideCursor + "\u{F015}")

        try await expectEventually {
            let missingPixels = missing.drawnColors().pixels(near: foreground)
            return missingPixels > 0 && icon.drawnColors().pixels(near: foreground) > missingPixels * 2
        }
    }
}
