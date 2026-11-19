import AppKit
import SwiftTerm

@MainActor
enum TerminalAppearanceStyling {
    static let minimumContrastRatio: CGFloat = 4.5

    @discardableResult
    static func apply(_ preferences: TerminalAppearancePreferences, theme: ResolvedAppTheme, to terminalView: TerminalView)
        -> TerminalPalette
    {
        let preferences = preferences.validated
        let usesDarkColors = preferences.mode.usesDarkColors(effectiveAppearance: terminalView.effectiveAppearance)
        let palette = preferences.colorVariants(appTheme: theme).palette(usesDarkColors: usesDarkColors)
        let scheme = palette.scheme
        let font = preferences.fontFamily.font(size: preferences.fontSize)
        // SwiftTerm clears selection and resizes the PTY when its font is assigned, even if unchanged.
        if terminalView.font != font { terminalView.font = font }
        terminalView.nativeForegroundColor = NSColor(hexValue: scheme.foreground)
        terminalView.nativeBackgroundColor = NSColor(hexValue: palette.background)
        terminalView.selectedTextBackgroundColor = NSColor(hexValue: scheme.selectionBackground)
        terminalView.selectedTextForegroundColor = NSColor(hexValue: scheme.readableSelectionForeground)
        terminalView.caretColor = NSColor(hexValue: scheme.foreground)
        terminalView.caretTextColor = NSColor(hexValue: palette.background)
        // Colors 16–255 are xterm's, as in Ghostty and most terminals. SwiftTerm's default blends them from the 16 ANSI
        // colors, which drained the color from the 256-color text Claude Code draws, most on themes with soft ANSI colors.
        terminalView.getTerminal().ansi256PaletteStrategy = .xterm
        terminalView.installColors(palette.ansiColors)
        terminalView.minimumContrastRatio = minimumContrastRatio
        terminalView.layer?.backgroundColor = terminalView.nativeBackgroundColor.cgColor
        terminalView.needsDisplay = true
        return palette
    }

    static func nativeAppearance(for preferences: TerminalAppearancePreferences, theme: ResolvedAppTheme) -> NSAppearance? {
        switch preferences.validated.colorVariants(appTheme: theme) {
        case .single(let palette): NSAppearance(named: palette.isDark ? .darkAqua : .aqua)
        case .lightAndDark: preferences.mode.nativeAppearance
        }
    }
}
