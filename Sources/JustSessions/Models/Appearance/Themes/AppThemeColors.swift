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
    /// Used where other apps put the system accent: the new-session badge and the selected tab text. The theme's own
    /// ink is darkened or lightened until it is readable on every surface in `textSurfaces`; Tokyo Night Day's blue is
    /// 4.0 on its sidebar.
    let ink: UInt32
    /// Text and glyphs drawn on top of `ink`.
    let inkForeground: UInt32
    /// Hover fills, tracks, and hairlines are this color at a low opacity.
    let line: UInt32
    let terminal: TerminalColorScheme
    let tabGroupHexColors: [UInt32]
    /// Each selected sidebar row's background, by its CLI; nil for a row without one.
    let selectedRowSurfaces: [ConversationProvider?: UInt32]
    /// Every background the app sets text on. The text colors below are readable on each of them.
    let textSurfaces: [UInt32]
    /// Supporting text: the theme's ink, faded toward the surface.
    let secondaryText: UInt32
    /// The faintest text, such as timestamps and counts: faded further than `secondaryText`.
    let tertiaryText: UInt32
    /// Text in the status hues of `StatusHexColors`.
    let warningText: UInt32
    let errorText: UInt32
    /// Text in each CLI's hue, such as its name above its messages.
    let providerTextHexColors: [ConversationProvider: UInt32]

    /// What the theme variant was made from, before its text was made readable. A customized theme starts from it.
    let seeds: AppThemeSeeds

    init(
        sidebarSurface: UInt32, contentSurface: UInt32, raisedSurface: UInt32, userMessageSurface: UInt32,
        ink: UInt32, inkForeground: UInt32, line: UInt32, terminal: TerminalColorScheme
    ) {
        self.init(seeds: AppThemeSeeds(
            sidebarSurface: sidebarSurface, contentSurface: contentSurface, raisedSurface: raisedSurface,
            userMessageSurface: userMessageSurface, ink: ink, inkForeground: inkForeground, line: line, terminal: terminal
        ))
    }

    init(seeds: AppThemeSeeds) {
        self.seeds = seeds
        sidebarSurface = seeds.sidebarSurface
        contentSurface = seeds.contentSurface
        raisedSurface = seeds.raisedSurface
        userMessageSurface = seeds.userMessageSurface
        line = seeds.line
        // Each immutable theme variant prepares its text colors and accents once, instead of doing contrast work while
        // drawing.
        let isDark = ThemeColorContrast.isDark(contentSurface)
        let selectedRowSurfaces = Self.selectedRowSurfaces(sidebarSurface: sidebarSurface, ink: seeds.ink, isDark: isDark)
        let textSurfaces = Self.textSurfaces(
            sidebarSurface: sidebarSurface, contentSurface: contentSurface, raisedSurface: raisedSurface,
            userMessageSurface: userMessageSurface, line: line, selectedRowSurfaces: selectedRowSurfaces
        )
        func readable(_ text: UInt32) -> UInt32 {
            ThemeColorContrast.readableText(text, on: textSurfaces)
        }
        let readableInk = readable(seeds.ink)
        self.selectedRowSurfaces = selectedRowSurfaces
        self.textSurfaces = textSurfaces
        ink = readableInk
        // The built-in themes' own pairs already read at 4.5, so only a customized theme's can change here.
        inkForeground = ThemeColorContrast.readableText(seeds.inkForeground, on: [readableInk])
        terminal = TerminalColorScheme(
            foreground: ThemeColorContrast.readableText(seeds.terminal.foreground, on: [contentSurface]),
            selectionBackground: seeds.terminal.selectionBackground,
            selectionForeground: seeds.terminal.selectionForeground,
            ansiHexColors: seeds.terminal.ansiHexColors
        )
        let secondaryText = readable(ThemeColorContrast.blend(readableInk, with: contentSurface, fraction: 0.35))
        let tertiaryText = readable(ThemeColorContrast.blend(readableInk, with: contentSurface, fraction: 0.55))
        self.secondaryText = secondaryText
        // Where both had to be made readable, tertiary can come out a shade stronger; it is never stronger than secondary.
        let tertiaryIsFainter = ThemeColorContrast.ratio(tertiaryText, contentSurface)
            <= ThemeColorContrast.ratio(secondaryText, contentSurface)
        self.tertiaryText = tertiaryIsFainter ? tertiaryText : secondaryText
        warningText = readable(StatusHexColors.warning.value(isDark: isDark))
        errorText = readable(StatusHexColors.error.value(isDark: isDark))
        providerTextHexColors = Dictionary(uniqueKeysWithValues: ConversationProvider.allCases.map { provider in
            (provider, readable(provider.tintHexColor.value(isDark: isDark)))
        })
        tabGroupHexColors = Self.tabGroupColors(
            ansiColors: seeds.terminal.ansiHexColors, labelSurfaces: [contentSurface, sidebarSurface]
        )
    }
}
