extension TerminalPalette {
    /// How far an ANSI color stands apart from the background at least, as a contrast ratio. A fill this far apart is
    /// plain to see; Nord's black, at 1.24, needs no change.
    static let minimumANSIFillRatio = 1.2

    /// The ANSI colors the terminal draws with: each moved away from the background until a fill in it can be seen. A
    /// program that fills cells with an ANSI color that is the background draws nothing. Claude Code held to 16
    /// colors fills its selection with black on a dark terminal and bright white on a light one, and Atom One Dark's
    /// black and Atom One Light's white are their backgrounds, as are colors an imported scheme can have.
    var distinguishableANSIHexColors: [UInt32] {
        scheme.ansiHexColors.map {
            ThemeColorContrast.distinguishableFill($0, on: background, minimumRatio: Self.minimumANSIFillRatio)
        }
    }
}
