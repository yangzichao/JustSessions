import Foundation

/// Reads what a program appends to a JSON Lines file as it goes: each call returns the lines written in full since the
/// last call. The first call returns none and starts from the end, since what the file held by then was read with the
/// session. A line still being written waits for its newline. A file that shrank was replaced, so reading starts again
/// from its new end. After a long gap, only the last `maximumCatchUpByteCount` bytes are read.
struct AppendedJSONLinesReader {
    static let maximumCatchUpByteCount: UInt64 = 262_144
    private static let newline = UInt8(ascii: "\n")

    let file: URL
    /// Where the next line starts; nil until the first call.
    private var readOffset: UInt64?

    init(file: URL) {
        self.file = file
    }

    /// The non-empty lines appended since the last call, oldest first; none when the file cannot be read.
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
              let lastNewline = appendedBytes.lastIndex(of: Self.newline) else { return [] }
        let completeLines = appendedBytes[...lastNewline]
        self.readOffset = startOffset + UInt64(completeLines.count)
        let lines = completeLines.split(separator: Self.newline).map { Data($0) }
        // Reading from partway into a line that started before the catch-up window cuts it off.
        return startOffset > readOffset ? Array(lines.dropFirst()) : lines
    }
}
