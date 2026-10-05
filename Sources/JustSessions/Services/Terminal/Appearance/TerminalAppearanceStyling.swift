import AppKit
import SwiftTerm

@MainActor
enum TerminalAppearanceStyling {
    /// Returns the palette the terminal took on.
    @discardableResult
    static func apply(_ preferences: TerminalAppearancePreferences, theme: AppTheme, to terminalView: TerminalView) -> TerminalPalette {
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
        terminalView.selectedTextForegroundColor = NSColor(hexValue: scheme.selectionForeground)
        terminalView.caretColor = NSColor(hexValue: scheme.foreground)
        terminalView.caretTextColor = NSColor(hexValue: palette.background)
        terminalView.installColors(scheme.ansiColors)
        terminalView.layer?.backgroundColor = terminalView.nativeBackgroundColor.cgColor
        terminalView.needsDisplay = true
        return palette
    }

    /// Nil lets the terminal inherit the app's appearance. A scheme with one version keeps the terminal light or
    /// dark to match its background, whatever the Appearance setting says.
    static func nativeAppearance(for preferences: TerminalAppearancePreferences, theme: AppTheme) -> NSAppearance? {
        switch preferences.validated.colorVariants(appTheme: theme) {
        case .single(let palette): NSAppearance(named: palette.isDark ? .darkAqua : .aqua)
        case .lightAndDark: preferences.mode.nativeAppearance
        }
    }
}
