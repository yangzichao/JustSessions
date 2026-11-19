import Foundation

struct PiLineHeadScanner {
    let line: Data
    let end: Data.Index
    private(set) var position: Data.Index

    init(line: Data, byteLimit: Int) {
        self.line = line
        end = line.startIndex + min(byteLimit, line.count)
        position = line.startIndex
    }

    mutating func skip(_ literal: String) -> Bool {
        var index = position
        for byte in literal.utf8 {
            guard index < end, line[index] == byte else { return false }
            index += 1
        }
        position = index
        return true
    }

    mutating func plainString() -> String? {
        guard let closingQuote = line[position..<end].firstIndex(of: UInt8(ascii: "\"")) else { return nil }
        let value = line[position..<closingQuote]
        guard !value.contains(UInt8(ascii: "\\")) else { return nil }
        position = closingQuote + 1
        return String(decoding: value, as: UTF8.self)
    }
}
