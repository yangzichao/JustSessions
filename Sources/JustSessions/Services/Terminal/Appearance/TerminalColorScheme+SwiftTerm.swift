import SwiftTerm

extension TerminalColorScheme {
    /// The ANSI colors in SwiftTerm's 16-bit components.
    var ansiColors: [SwiftTerm.Color] {
        ansiHexColors.map { hexValue in
            SwiftTerm.Color(
                red: UInt16((hexValue >> 16) & 0xFF) * 257,
                green: UInt16((hexValue >> 8) & 0xFF) * 257,
                blue: UInt16(hexValue & 0xFF) * 257
            )
        }
    }
}
