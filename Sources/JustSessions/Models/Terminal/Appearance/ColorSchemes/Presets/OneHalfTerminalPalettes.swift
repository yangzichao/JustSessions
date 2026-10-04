/// One Half Light and One Half Dark, from sonph/onehalf 75eb2e9's iTerm2 colors.
extension TerminalPalette {
    static let oneHalfLight = TerminalPalette(
        background: 0xFAFAFA,
        scheme: TerminalColorScheme(
            foreground: 0x383A42,
            selectionBackground: 0xBFCEFF,
            selectionForeground: 0x383A42,
            ansiHexColors: [
                0x383A42, 0xE45649, 0x50A14F, 0xC18401,
                0x0184BC, 0xA626A4, 0x0997B3, 0xFAFAFA,
                0x4F525E, 0xE06C75, 0x98C379, 0xE5C07B,
                0x61AFEF, 0xC678DD, 0x56B6C2, 0xFFFFFF,
            ]
        )
    )

    static let oneHalfDark = TerminalPalette(
        background: 0x282C34,
        scheme: TerminalColorScheme(
            foreground: 0xDCDFE4,
            selectionBackground: 0x474E5D,
            selectionForeground: 0xDCDFE4,
            ansiHexColors: [
                // The iTerm2 colors make bright black the background color, which hides dim text and hints, so
                // bright black comes from the same repository's kitty colors.
                0x282C34, 0xE06C75, 0x98C379, 0xE5C07B,
                0x61AFEF, 0xC678DD, 0x56B6C2, 0xDCDFE4,
                0x5D677A, 0xE06C75, 0x98C379, 0xE5C07B,
                0x61AFEF, 0xC678DD, 0x56B6C2, 0xDCDFE4,
            ]
        )
    )
}
