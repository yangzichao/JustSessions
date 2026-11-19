import Foundation

/// The model a Codex session used last: the `model` and `effort` of the last `turn_context` line in its rollout file,
/// which Codex writes as each turn starts, such as
/// `{"type":"turn_context","payload":{"model":"gpt-5.5","effort":"medium",…}}`.
///
/// A long turn writes megabytes after its `turn_context`, so the line is looked for from the end backwards, a chunk at
/// a time, as raw bytes; only the line found is parsed.
enum CodexRolloutModel {
    static let chunkByteCount = 1 << 20
    private static let marker = Data(#""type":"turn_context""#.utf8)
    private static let newline = UInt8(ascii: "\n")

    /// Nil when the file has no `turn_context` naming a model, or can't be read.
    static func latest(in file: URL) -> SessionModel? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size > 0 else { return nil }
        var searchEnd = size
        while searchEnd > 0 {
            // Each chunk overlaps the one after it by the marker's length, so a marker cut by the boundary is found.
            let chunkStart = searchEnd > UInt64(chunkByteCount) ? searchEnd - UInt64(chunkByteCount) : 0
            let readEnd = min(size, searchEnd + UInt64(marker.count))
            guard let chunk = read(handle, from: chunkStart, to: readEnd) else { return nil }
            var rangeEnd = chunk.endIndex
            while let found = chunk.range(of: marker, options: .backwards, in: chunk.startIndex..<rangeEnd) {
                let offset = chunkStart + UInt64(found.lowerBound - chunk.startIndex)
                if let model = model(inLineAt: offset, of: handle, size: size) { return model }
                rangeEnd = found.lowerBound
            }
            searchEnd = chunkStart
        }
        return nil
    }

    /// The model named by the `turn_context` line holding the byte at `offset`.
    private static func model(inLineAt offset: UInt64, of handle: FileHandle, size: UInt64) -> SessionModel? {
        guard let line = line(around: offset, of: handle, size: size),
            let record = ConversationMetadata.object(from: line),
            record["type"] as? String == "turn_context",
            let payload = record["payload"] as? [String: Any]
        else { return nil }
        return SessionModel(id: payload["model"] as? String, effort: payload["effort"] as? String)
    }

    /// The whole line around `offset`, read outwards a chunk at a time.
    private static func line(around offset: UInt64, of handle: FileHandle, size: UInt64) -> Data? {
        var start = offset
        while start > 0 {
            let from = start > UInt64(chunkByteCount) ? start - UInt64(chunkByteCount) : 0
            guard let before = read(handle, from: from, to: start) else { return nil }
            if let newlineIndex = before.lastIndex(of: newline) {
                start = from + UInt64(newlineIndex - before.startIndex) + 1
                break
            }
            start = from
        }
        var end = offset
        while end < size {
            let to = min(size, end + UInt64(chunkByteCount))
            guard let after = read(handle, from: end, to: to) else { return nil }
            if let newlineIndex = after.firstIndex(of: newline) {
                end += UInt64(newlineIndex - after.startIndex)
                break
            }
            end = to
        }
        return read(handle, from: start, to: end)
    }

    private static func read(_ handle: FileHandle, from start: UInt64, to end: UInt64) -> Data? {
        guard end > start else { return Data() }
        return autoreleasepool {
            guard (try? handle.seek(toOffset: start)) != nil else { return nil }
            return try? handle.read(upToCount: Int(end - start))
        }
    }
}
