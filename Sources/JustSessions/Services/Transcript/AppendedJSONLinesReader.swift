import Foundation

struct AppendedJSONLinesReader {
    static let maximumCatchUpByteCount: UInt64 = 262_144
    private static let newline = UInt8(ascii: "\n")

    let file: URL
    private var readOffset: UInt64?

    init(file: URL) {
        self.file = file
    }

    mutating func newLines() -> [Data] {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return [] }
        defer { try? handle.close() }
        guard let endOffset = try? handle.seekToEnd() else { return [] }
        guard let readOffset, readOffset <= endOffset else {
            self.readOffset = endOffset
            return []
        }
        guard endOffset > readOffset else { return [] }

        let startOffset = max(readOffset, endOffset - min(endOffset, Self.maximumCatchUpByteCount))
        guard (try? handle.seek(toOffset: startOffset)) != nil,
            let appendedBytes = try? handle.readToEnd(),
            let lastNewline = appendedBytes.lastIndex(of: Self.newline)
        else { return [] }
        let completeLines = appendedBytes[...lastNewline]
        self.readOffset = startOffset + UInt64(completeLines.count)
        let lines = completeLines.split(separator: Self.newline).map { Data($0) }
        return startOffset > readOffset ? Array(lines.dropFirst()) : lines
    }
}
