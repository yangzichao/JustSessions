import AppKit
import SwiftTerm

@MainActor
enum TerminalAppearanceStyling {
    static func apply(_ preferences: TerminalAppearancePreferences, theme: AppTheme, to terminalView: TerminalView) {
        let preferences = preferences.validated
        let colors = theme.colors(isDark: preferences.mode.usesDarkColors(effectiveAppearance: terminalView.effectiveAppearance))
        let scheme = colors.terminal
        let font = preferences.fontFamily.font(size: preferences.fontSize)
        // SwiftTerm clears selection and resizes the PTY when its font is assigned, even if unchanged.
        if terminalView.font != font { terminalView.font = font }
        terminalView.nativeForegroundColor = NSColor(hexValue: scheme.foreground)
        terminalView.nativeBackgroundColor = NSColor(hexValue: colors.contentSurface)
        terminalView.selectedTextBackgroundColor = NSColor(hexValue: scheme.selectionBackground)
        terminalView.selectedTextForegroundColor = NSColor(hexValue: scheme.selectionForeground)
        terminalView.caretColor = NSColor(hexValue: scheme.foreground)
        terminalView.caretTextColor = NSColor(hexValue: colors.contentSurface)
        terminalView.installColors(scheme.ansiColors)
        terminalView.layer?.backgroundColor = terminalView.nativeBackgroundColor.cgColor
        terminalView.needsDisplay = true
    }
}
