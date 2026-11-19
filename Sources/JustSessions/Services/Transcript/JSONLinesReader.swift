import Foundation

enum JSONLinesReader {
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
            let chunk = try? handle.read(upToCount: min(chunkSize, remainingByteCount)), !chunk.isEmpty
        {
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

    static func leadingLines(in file: URL, maximumByteCount: Int) -> [Data] {
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            return try nonEmptyLines(in: handle.read(upToCount: maximumByteCount) ?? Data())
        } catch {
            return []
        }
    }

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
