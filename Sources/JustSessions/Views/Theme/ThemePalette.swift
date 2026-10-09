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
    /// Supporting copy, using the chosen theme's ink with sufficient contrast on its surfaces. Use it in place of the
    /// system's `.secondary`, which is 3.0 on light surfaces.
    static let secondaryText = ThemeColor(role: .secondaryText)
    /// The faintest copy, such as timestamps and counts, still readable. Use it in place of the system's `.tertiary`,
    /// which is 1.7 on light surfaces.
    static let tertiaryText = ThemeColor(role: .tertiaryText)
    /// Faint fills: the pointer over a row, a track behind a segmented control.
    static let hoverFill = ThemeColor(role: .line, opacity: ThemeFillOpacity.hover)
    /// Held-down controls: clearly stronger than the pointer's hover surface in either appearance.
    static let pressedFill = ThemeColor(role: .line, opacity: ThemeFillOpacity.pressed)
    static let trackFill = ThemeColor(role: .line, opacity: ThemeFillOpacity.track)
    /// Hairlines between regions and around raised controls.
    static let hairline = ThemeColor(role: .line, opacity: ThemeFillOpacity.hairline)

    // MARK: Status

    /// Status glyphs, in the hues of `StatusHexColors`. Text in these hues uses the readable versions below.
    static let live = Color.adaptive(StatusHexColors.live)
    static let warning = Color.adaptive(StatusHexColors.warning)
    static let unseenTurn = Color.adaptive(StatusHexColors.unseenTurn)
    static let warningText = ThemeColor(role: .warningText)
    static let errorText = ThemeColor(role: .errorText)
}
