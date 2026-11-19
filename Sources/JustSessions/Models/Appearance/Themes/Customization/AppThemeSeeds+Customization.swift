extension AppThemeSeeds {
    static let minimumSelectionContrast = 1.25

    func applying(_ changedColors: [CustomizableThemeColor: UInt32]) -> AppThemeSeeds {
        var seeds = self
        for (color, value) in changedColors {
            switch color {
            case .contentSurface: seeds.contentSurface = value
            case .sidebarSurface: seeds.sidebarSurface = value
            case .raisedSurface: seeds.raisedSurface = value
            case .userMessageSurface: seeds.userMessageSurface = value
            case .ink: break
            }
        }
        if let ink = changedColors[.ink] {
            let readableInk = ThemeColorContrast.readableText(ink, on: seeds.surfaces)
            seeds.ink = readableInk
            seeds.line = readableInk
        }
        if changedColors[.contentSurface] != nil {
            seeds.terminal = seeds.terminal.withSelection(standingOutFrom: seeds.contentSurface)
        }
        return seeds
    }

    func surfacesSuit(isDark: Bool) -> Bool {
        guard surfaces.allSatisfy({ ThemeColorContrast.isDark($0) == isDark }) else { return false }
        let strongestInk: UInt32 = isDark ? 0xFFFFFF : 0x000000
        let textSurfaces = AppThemeColors.textSurfaces(
            sidebarSurface: sidebarSurface, contentSurface: contentSurface, raisedSurface: raisedSurface,
            userMessageSurface: userMessageSurface, line: strongestInk,
            selectedRowSurfaces: AppThemeColors.selectedRowSurfaces(sidebarSurface: sidebarSurface, ink: strongestInk, isDark: isDark)
        )
        return textSurfaces.allSatisfy { ThemeColorContrast.ratio(strongestInk, $0) >= ThemeColorContrast.minimumTextRatio }
    }

    private var surfaces: [UInt32] {
        [contentSurface, sidebarSurface, raisedSurface, userMessageSurface]
    }
}

extension TerminalColorScheme {
    fileprivate func withSelection(standingOutFrom background: UInt32) -> TerminalColorScheme {
        let contrast = ThemeColorContrast.ratio(selectionBackground, background)
        guard contrast < AppThemeSeeds.minimumSelectionContrast else { return self }
        return TerminalColorScheme(
            foreground: foreground,
            selectionBackground: ThemeColorContrast.blend(background, with: foreground, fraction: 0.3),
            selectionForeground: selectionForeground,
            ansiHexColors: ansiHexColors
        )
    }
}
