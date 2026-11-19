extension AppThemeColors {
    static func tabGroupColors(ansiColors: [UInt32], labelSurfaces: [UInt32]) -> [UInt32] {
        let candidateColors = [
            ansiColors[4],
            ansiColors[1],
            ansiColors[3],
            ansiColors[2],
            ThemeColorContrast.blend(ansiColors[1], with: ansiColors[5], fraction: 0.5),
            ansiColors[5],
            ansiColors[6],
            ThemeColorContrast.blend(ansiColors[1], with: ansiColors[3], fraction: 0.5),
        ]
        return candidateColors.map { candidateColor in
            ThemeColorContrast.readableAccent(candidateColor, on: labelSurfaces)
        }
    }
}
