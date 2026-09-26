import Foundation

enum JSONLinesReader {
    /// Calls `body` with each non-empty line, reading in chunks so a large session file is never loaded at once.
    /// Throws `CancellationError` between chunks when the calling task is cancelled.
    static func forEachLine(in file: URL, chunkSize: Int = 1 << 20, _ body: (Data) throws -> Void) throws {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var buffer = Data()
        var bytesKnownWithoutNewline = 0
        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            try Task.checkCancellation()
            buffer.append(chunk)
            var lineStart = buffer.startIndex
            var searchStart = buffer.startIndex + bytesKnownWithoutNewline
            while let newline = buffer[searchStart...].firstIndex(of: UInt8(ascii: "\n")) {
                if newline > lineStart { try body(buffer[lineStart..<newline]) }
                lineStart = newline + 1
                searchStart = lineStart
            }
            buffer.removeSubrange(buffer.startIndex..<lineStart)
            bytesKnownWithoutNewline = buffer.count
        }
        if !buffer.isEmpty { try body(buffer) }
    }
}
