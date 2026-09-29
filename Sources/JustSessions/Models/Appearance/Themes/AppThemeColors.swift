/// One theme's colors in light or in dark, as 0xRRGGBB values. Saturated color stays out of the theme: each CLI keeps
/// its brand hue, and running and attention states keep their green and amber.
struct AppThemeColors: Equatable, Sendable {
    /// Behind the sidebar, setting the list apart from the reading surface.
    let sidebarSurface: UInt32
    /// Behind the preview, the tab bar, and terminals.
    let contentSurface: UInt32
    /// Raised controls on a surface: the search field, the selected segment, the selected tab.
    let raisedSurface: UInt32
    /// Your messages in a transcript.
    let userMessageSurface: UInt32
    /// Used where other apps put the system accent: the new-session badge and the selected tab text.
    let ink: UInt32
    /// Text and glyphs drawn on top of `ink`.
    let inkForeground: UInt32
    /// Hover fills, tracks, and hairlines are this color at a low opacity.
    let line: UInt32
    let terminal: TerminalColorScheme
}
