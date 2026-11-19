extension AppThemeColors {
    static let selectedRowProviders: [ConversationProvider?] = ConversationProvider.allCases + [nil]

    /// A selected sidebar row's background: the sidebar washed in the row's CLI hue, or in the ink. Views draw this
    /// opaque color, not the hue at an opacity, because a window blends a translucent fill in the display's color
    /// space. On a P3 display Claude's orange came out lighter than this blend, and Tokyo Night's text on it fell below
    /// 4.5.
    static func selectedRowSurfaces(sidebarSurface: UInt32, ink: UInt32, isDark: Bool) -> [ConversationProvider?: UInt32] {
        Dictionary(
            uniqueKeysWithValues: selectedRowProviders.map { provider in
                let hue = provider?.tintHexColor.value(isDark: isDark) ?? ink
                return (provider, ThemeColorContrast.blend(sidebarSurface, with: hue, fraction: ThemeFillOpacity.selectedRow))
            })
    }

    static func textSurfaces(
        sidebarSurface: UInt32, contentSurface: UInt32, raisedSurface: UInt32, userMessageSurface: UInt32,
        line: UInt32, selectedRowSurfaces: [ConversationProvider?: UInt32]
    ) -> [UInt32] {
        let faintlyFilledSurfaces = [ThemeFillOpacity.hover, ThemeFillOpacity.track].flatMap { opacity in
            [sidebarSurface, contentSurface].map { ThemeColorContrast.blend($0, with: line, fraction: opacity) }
        }
        return [contentSurface, sidebarSurface, raisedSurface, userMessageSurface]
            + faintlyFilledSurfaces
            + selectedRowProviders.compactMap { selectedRowSurfaces[$0] }
    }
}
