/// One theme's colors in light or in dark, as 0xRRGGBB values. Saturated color stays out of the theme: each CLI keeps
/// its brand hue, and running and attention states keep their green and amber.
struct AppThemeColors: Equatable, Sendable {
    /// Behind the sidebar and the tab bar, setting them apart from the reading surface.
    let sidebarSurface: UInt32
    /// Behind the preview and terminals.
    let contentSurface: UInt32
    /// Raised controls on a surface: the search field and the selected segment.
    let raisedSurface: UInt32
    /// Your messages in a transcript.
    let userMessageSurface: UInt32
    /// Used where other apps put the system accent: the new-session badge and the selected tab text.
    let ink: UInt32
    /// Text and glyphs drawn on top of `ink`.
    let inkForeground: UInt32
    /// Supporting text on either content or raised surfaces.
    let secondaryText: UInt32
    /// Hover fills, tracks, and hairlines are this color at a low opacity.
    let line: UInt32
    let terminal: TerminalColorScheme
    let tabGroupHexColors: [UInt32]

    init(
        sidebarSurface: UInt32, contentSurface: UInt32, raisedSurface: UInt32, userMessageSurface: UInt32,
        ink: UInt32, inkForeground: UInt32, line: UInt32, terminal: TerminalColorScheme
    ) {
        self.sidebarSurface = sidebarSurface
        self.contentSurface = contentSurface
        self.raisedSurface = raisedSurface
        self.userMessageSurface = userMessageSurface
        self.ink = ink
        self.inkForeground = inkForeground
        secondaryText = ThemeColorContrast.readableText(
            ThemeColorContrast.blend(ink, with: contentSurface, fraction: 0.35), on: [contentSurface, raisedSurface]
        )
        self.line = line
        self.terminal = terminal
        // Each immutable theme variant prepares its accents once, instead of doing contrast work while drawing.
        tabGroupHexColors = Self.tabGroupColors(ansiColors: terminal.ansiHexColors, contentSurface: contentSurface)
    }
}
