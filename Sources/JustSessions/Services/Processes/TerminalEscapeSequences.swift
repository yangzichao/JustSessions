import Foundation

/// Some CLIs color their errors even when their output is not a terminal; an alert should show only the words.
enum TerminalEscapeSequences {
    /// Removes control sequences such as `ESC [ 91 m` (ESC, `[`, parameter and intermediate bytes, then one final
    /// byte) and two-character escapes such as `ESC c`.
    static func removed(from text: String) -> String {
        var result = String.UnicodeScalarView()
        var scalars = text.unicodeScalars.makeIterator()
        while let scalar = scalars.next() {
            guard scalar == "\u{1B}" else {
                result.append(scalar)
                continue
            }
            guard let next = scalars.next(), next == "[" else { continue }
            while let sequenceScalar = scalars.next(), !(0x40...0x7E).contains(sequenceScalar.value) {}
        }
        return String(result)
    }
}
