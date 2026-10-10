extension AppThemeSeeds {
    /// The least a built-in theme's terminal selection stands out from its background, JustSessions light's.
    static let minimumSelectionContrast = 1.25

    /// These seeds with the changed colors in place of their own.
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
            // A picked ink is drawn readable on the surfaces. Hairlines, hover fills, and the selected row take that
            // color, not the pick, so they stay as visible as a built-in theme's when the pick is pale.
            let readableInk = ThemeColorContrast.readableText(ink, on: seeds.surfaces)
            seeds.ink = readableInk
            seeds.line = readableInk
        }
        if changedColors[.contentSurface] != nil {
            seeds.terminal = seeds.terminal.withSelection(standingOutFrom: seeds.contentSurface)
        }
        return seeds
    }

    /// Whether text stays readable on these surfaces whatever the ink: they are all light, or all dark, and the
    /// strongest text, black or white, reads at 4.5 on each of them under the strongest hover fill and selected-row
    /// wash any ink could give it. Each surface is checked on its own, so any ink, and a surface given back its theme's
    /// own color, keeps every text color readable.
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

    /// The content surface first, which decides whether text is darkened or lightened.
    private var surfaces: [UInt32] {
        [contentSurface, sidebarSurface, raisedSurface, userMessageSurface]
    }
}

private extension TerminalColorScheme {
    /// The scheme with its selection kept where it still stands out from a new background, and otherwise the
    /// background blended toward the text, as imported colors without a selection color get.
    func withSelection(standingOutFrom background: UInt32) -> TerminalColorScheme {
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
