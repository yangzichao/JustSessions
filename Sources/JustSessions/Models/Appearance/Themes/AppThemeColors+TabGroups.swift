extension AppThemeColors {
    /// Project accents use the theme's hues, with extra contrast for text on the tinted group label.
    static func tabGroupColors(ansiColors: [UInt32], contentSurface: UInt32) -> [UInt32] {
        let candidateColors = [
            ansiColors[4], // blue
            ansiColors[1], // red
            ansiColors[3], // amber
            ansiColors[2], // green
            ThemeColorContrast.blend(ansiColors[1], with: ansiColors[5], fraction: 0.5), // pink
            ansiColors[5], // purple
            ansiColors[6], // cyan
            ThemeColorContrast.blend(ansiColors[1], with: ansiColors[3], fraction: 0.5), // orange
        ]
        return candidateColors.map { candidateColor in
            ThemeColorContrast.readableAccent(candidateColor, on: contentSurface)
        }
    }
}
