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

    /// Calls `body` with each non-empty line in the first `maximumByteCount` bytes of `file`, oldest first, until it
    /// returns false, reading only as far as that. The last line may be cut off at the limit. Nothing is read when
    /// the file cannot be opened.
    static func forEachLeadingLine(
        in file: URL,
        maximumByteCount: Int,
        chunkSize: Int = 65_536,
        _ body: (Data) -> Bool
    ) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }
        var buffer = Data()
        var bytesKnownWithoutNewline = 0
        var remainingByteCount = maximumByteCount
        while remainingByteCount > 0,
              let chunk = try? handle.read(upToCount: min(chunkSize, remainingByteCount)), !chunk.isEmpty {
            remainingByteCount -= chunk.count
            buffer.append(chunk)
            var lineStart = buffer.startIndex
            var searchStart = buffer.startIndex + bytesKnownWithoutNewline
            while let newline = buffer[searchStart...].firstIndex(of: UInt8(ascii: "\n")) {
                if newline > lineStart, !body(Data(buffer[lineStart..<newline])) { return }
                lineStart = newline + 1
                searchStart = lineStart
            }
            buffer.removeSubrange(buffer.startIndex..<lineStart)
            bytesKnownWithoutNewline = buffer.count
        }
        if !buffer.isEmpty { _ = body(buffer) }
    }

    /// The non-empty lines in the first `maximumByteCount` bytes of `file`, or none when it cannot be read. The last
    /// line may be cut off at the limit.
    static func leadingLines(in file: URL, maximumByteCount: Int) -> [Data] {
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            return try nonEmptyLines(in: handle.read(upToCount: maximumByteCount) ?? Data())
        } catch {
            return []
        }
    }

    /// The non-empty lines in the last `maximumByteCount` bytes of `file`, oldest first, or none when it cannot be
    /// read. When those bytes start partway into the file, their first line is left out, since it may be cut off.
    static func trailingLines(in file: URL, maximumByteCount: Int) -> [Data] {
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            let length = try handle.seekToEnd()
            let windowStart = length > UInt64(maximumByteCount) ? length - UInt64(maximumByteCount) : 0
            try handle.seek(toOffset: windowStart)
            let lines = try nonEmptyLines(in: handle.readToEnd() ?? Data())
            return windowStart > 0 ? Array(lines.dropFirst()) : lines
        } catch {
            return []
        }
    }

    private static func nonEmptyLines(in data: Data) -> [Data] {
        data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true).map { Data($0) }
    }
}
