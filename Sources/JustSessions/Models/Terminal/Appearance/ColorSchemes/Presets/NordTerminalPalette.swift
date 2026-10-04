/// Nord has only a dark version. Colors from nordtheme/iterm2 233a246, converted from its calibrated RGB to sRGB.
extension TerminalPalette {
    static let nord = TerminalPalette(
        background: 0x2E3440,
        scheme: TerminalColorScheme(
            foreground: 0xD8DEE9,
            selectionBackground: 0x4C566A,
            selectionForeground: 0xD8DEE9,
            ansiHexColors: [
                0x3B4252, 0xBF616A, 0xA3BE8C, 0xEBCB8B,
                0x81A1C1, 0xB48EAD, 0x88C0D0, 0xE5E9F0,
                0x4C566A, 0xBF616A, 0xA3BE8C, 0xEBCB8B,
                0x81A1C1, 0xB48EAD, 0x8FBCBB, 0xECEFF4,
            ]
        )
    )
}
