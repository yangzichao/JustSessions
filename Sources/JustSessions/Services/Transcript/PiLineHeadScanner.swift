import Foundation

/// Steps through the first bytes of a Pi session line, matching exact text and reading plain string values.
struct PiLineHeadScanner {
    let bytes: [UInt8]
    private(set) var position = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    /// Moves past `literal` when the bytes continue with it exactly; otherwise stays put.
    mutating func skip(_ literal: String) -> Bool {
        let literalBytes = Array(literal.utf8)
        let end = position + literalBytes.count
        guard end <= bytes.count, bytes[position..<end].elementsEqual(literalBytes) else { return false }
        position = end
        return true
    }

    /// The string value whose opening quote was just skipped, moving past its closing quote. Nil when the value is
    /// cut off or holds an escape, which could spell it differently, so the line is parsed instead.
    mutating func plainString() -> String? {
        guard let closingQuote = bytes[position...].firstIndex(of: UInt8(ascii: "\"")) else { return nil }
        let value = bytes[position..<closingQuote]
        guard !value.contains(UInt8(ascii: "\\")) else { return nil }
        position = closingQuote + 1
        return String(decoding: value, as: UTF8.self)
    }
}
