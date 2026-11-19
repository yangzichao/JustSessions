extension TerminalPalette {
    /// The palette with its 16 ANSI colors at `percent` intensity; see `TerminalColorIntensity`. The background, text,
    /// and selection colors stay as they are.
    func withANSIColorIntensity(percent: Int) -> TerminalPalette {
        guard percent != TerminalColorIntensity.defaultPercent else { return self }
        return TerminalPalette(
            background: background,
            scheme: TerminalColorScheme(
                foreground: scheme.foreground,
                selectionBackground: scheme.selectionBackground,
                selectionForeground: scheme.selectionForeground,
                ansiHexColors: scheme.ansiHexColors.map { TerminalColorIntensity.adjusted($0, percent: percent) }
            ))
    }
}

extension TerminalPaletteVariants {
    /// Each version's ANSI colors at `percent` intensity.
    func withANSIColorIntensity(percent: Int) -> TerminalPaletteVariants {
        switch self {
        case .single(let palette):
            .single(palette.withANSIColorIntensity(percent: percent))
        case .lightAndDark(let light, let dark):
            .lightAndDark(light: light.withANSIColorIntensity(percent: percent), dark: dark.withANSIColorIntensity(percent: percent))
        }
    }
}
