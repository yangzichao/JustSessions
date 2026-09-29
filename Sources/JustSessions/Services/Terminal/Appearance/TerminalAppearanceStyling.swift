import AppKit
import SwiftTerm

@MainActor
enum TerminalAppearanceStyling {
    static func apply(_ preferences: TerminalAppearancePreferences, to terminalView: TerminalView) {
        let preferences = preferences.validated
        let scheme: TerminalColorScheme = preferences.mode.usesDarkPalette(effectiveAppearance: terminalView.effectiveAppearance)
            ? .charcoal : .paper
        let font = preferences.fontFamily.font(size: preferences.fontSize)
        // SwiftTerm clears selection and resizes the PTY when its font is assigned, even if unchanged.
        if terminalView.font != font { terminalView.font = font }
        terminalView.nativeForegroundColor = NSColor(hexValue: scheme.foreground)
        terminalView.nativeBackgroundColor = NSColor(hexValue: scheme.background)
        terminalView.selectedTextBackgroundColor = NSColor(hexValue: scheme.selectionBackground)
        terminalView.selectedTextForegroundColor = NSColor(hexValue: scheme.selectionForeground)
        terminalView.caretColor = NSColor(hexValue: scheme.foreground)
        terminalView.caretTextColor = NSColor(hexValue: scheme.background)
        terminalView.installColors(scheme.ansiColors)
        terminalView.layer?.backgroundColor = terminalView.nativeBackgroundColor.cgColor
        terminalView.needsDisplay = true
    }
}
