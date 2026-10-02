import Foundation

/// Steps through the first bytes of a Pi session line, matching exact text and reading plain string values. It reads
/// the line's own bytes in place, so scanning a line copies nothing but the strings it returns.
struct PiLineHeadScanner {
    let line: Data
    /// Where the bytes the scanner may read end: `byteLimit` bytes into the line, or the line's end if sooner.
    let end: Data.Index
    private(set) var position: Data.Index

    init(line: Data, byteLimit: Int) {
        self.line = line
        end = line.startIndex + min(byteLimit, line.count)
        position = line.startIndex
    }

    /// Moves past `literal` when the bytes continue with it exactly; otherwise stays put.
    mutating func skip(_ literal: String) -> Bool {
        var index = position
        for byte in literal.utf8 {
            guard index < end, line[index] == byte else { return false }
            index += 1
        }
        position = index
        return true
    }

    /// The string value whose opening quote was just skipped, moving past its closing quote. Nil when the value is
    /// cut off or holds an escape, which could spell it differently, so the line is parsed instead.
    mutating func plainString() -> String? {
        guard let closingQuote = line[position..<end].firstIndex(of: UInt8(ascii: "\"")) else { return nil }
        let value = line[position..<closingQuote]
        guard !value.contains(UInt8(ascii: "\\")) else { return nil }
        position = closingQuote + 1
        return String(decoding: value, as: UTF8.self)
    }
}
