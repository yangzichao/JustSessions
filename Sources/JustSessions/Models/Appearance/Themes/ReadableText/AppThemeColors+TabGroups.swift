extension AppThemeColors {
    static func tabGroupColors(terminal: TerminalColorScheme, labelSurfaces: [UInt32]) -> [UInt32] {
        let pink = ThemeColorContrast.blend(terminal.ansiRed, with: terminal.ansiMagenta, fraction: 0.5)
        let orange = ThemeColorContrast.blend(terminal.ansiRed, with: terminal.ansiYellow, fraction: 0.5)
        let candidateColors = [
            terminal.ansiBlue,
            terminal.ansiRed,
            terminal.ansiYellow,
            terminal.ansiGreen,
            pink,
            terminal.ansiMagenta,
            terminal.ansiCyan,
            orange,
        ]
        return candidateColors.map { candidateColor in
            ThemeColorContrast.readableAccent(candidateColor, on: labelSurfaces)
        }
    }
}
