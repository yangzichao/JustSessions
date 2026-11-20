struct AppThemeColors: Equatable, Sendable {
    let sidebarSurface: UInt32
    let contentSurface: UInt32
    let raisedSurface: UInt32
    let userMessageSurface: UInt32
    let ink: UInt32
    let inkForeground: UInt32
    let line: UInt32
    let terminal: TerminalColorScheme
    let tabGroupHexColors: [UInt32]
    let selectedRowSurfaces: [ConversationProvider?: UInt32]
    let textSurfaces: [UInt32]
    let secondaryText: UInt32
    let tertiaryText: UInt32
    let warningText: UInt32
    let errorText: UInt32
    let providerTextHexColors: [ConversationProvider: UInt32]

    let seeds: AppThemeSeeds

    init(
        sidebarSurface: UInt32, contentSurface: UInt32, raisedSurface: UInt32, userMessageSurface: UInt32,
        ink: UInt32, inkForeground: UInt32, line: UInt32, terminal: TerminalColorScheme
    ) {
        self.init(
            seeds: AppThemeSeeds(
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
        let tertiaryIsFainter =
            ThemeColorContrast.ratio(tertiaryText, contentSurface)
            <= ThemeColorContrast.ratio(secondaryText, contentSurface)
        self.tertiaryText = tertiaryIsFainter ? tertiaryText : secondaryText
        warningText = readable(StatusHexColors.warning.value(isDark: isDark))
        errorText = readable(StatusHexColors.error.value(isDark: isDark))
        providerTextHexColors = Dictionary(
            uniqueKeysWithValues: ConversationProvider.allCases.map { provider in
                (provider, readable(provider.tintHexColor.value(isDark: isDark)))
            })
        tabGroupHexColors = Self.tabGroupColors(
            terminal: seeds.terminal, labelSurfaces: [contentSurface, sidebarSurface]
        )
    }
}
