import SwiftUI

/// The app's colors. Surfaces and the ink come from the theme chosen in Settings (see `AppThemeColors`), and
/// saturated color is kept for meaning: each CLI's brand hue, the green of a running CLI, and the amber of what needs
/// your attention.
enum ThemePalette {
    // MARK: Surfaces

    /// Behind the sidebar, reaching up behind the title bar, and behind the tab bar.
    static let sidebarSurface = ThemeColor(role: .sidebarSurface)
    /// Behind the preview and terminals.
    static let contentSurface = ThemeColor(role: .contentSurface)
    /// Raised controls on a surface: the search field and the selected segment.
    static let raisedSurface = ThemeColor(role: .raisedSurface)
    /// Your messages in a transcript.
    static let userMessageSurface = ThemeColor(role: .userMessageSurface)

    // MARK: Ink

    /// Used where other apps put the system accent: the new-session badge and the selected tab text.
    static let ink = ThemeColor(role: .ink)
    /// Text and glyphs drawn on top of `ink`.
    static let inkForeground = ThemeColor(role: .inkForeground)
    /// Supporting copy, using the chosen theme's ink with sufficient contrast on its surfaces.
    static let secondaryText = ThemeColor(role: .secondaryText)
    /// Faint fills: the pointer over a row, a track behind a segmented control.
    static let hoverFill = ThemeColor(role: .line, opacity: 0.055)
    static let trackFill = ThemeColor(role: .line, opacity: 0.06)
    /// Hairlines between regions and around raised controls.
    static let hairline = ThemeColor(role: .line, opacity: 0.09)

    // MARK: Status

    /// A running CLI.
    static let live = Color.adaptive(light: 0x1FA463, dark: 0x3DD68C)
    /// Something that needs your attention, such as a CLI waiting on your answer or an unreachable remote host.
    static let warning = Color.adaptive(light: 0xE0892B, dark: 0xF2A54A)
}
