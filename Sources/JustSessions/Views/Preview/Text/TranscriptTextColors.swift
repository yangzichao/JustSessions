import AppKit

struct TranscriptTextColors: Equatable {
    let primary: NSColor
    let secondary: NSColor
    let tertiary: NSColor
    let link: NSColor
    let matchHighlight: NSColor
    let selectedMatchForeground: NSColor

    init(theme: ResolvedAppTheme, isDark: Bool) {
        primary = .labelColor
        secondary = ThemePalette.secondaryText.nsColor(in: theme, isDark: isDark)
        tertiary = ThemePalette.tertiaryText.nsColor(in: theme, isDark: isDark)
        link = ThemePalette.ink.nsColor(in: theme, isDark: isDark)
        matchHighlight = link
        selectedMatchForeground = ThemePalette.inkForeground.nsColor(in: theme, isDark: isDark)
    }

    func foreground(for tone: TranscriptTextTone) -> NSColor {
        switch tone {
        case .primary: primary
        case .secondary: secondary
        case .tertiary: tertiary
        }
    }
}
