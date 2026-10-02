import Foundation

/// Only byte offsets are retained, never JSON objects or message text. A 100,000-line log needs about 0.8 MiB.
struct TranscriptFileIndex: Sendable {
    let lineStarts: [UInt64]
    let byteCount: UInt64

    static func read(_ file: URL, chunkSize: Int = 1 << 20) throws -> Self {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let byteCount = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        var lineStarts: [UInt64] = byteCount == 0 ? [] : [0]
        var offset: UInt64 = 0
        while offset < byteCount {
            try Task.checkCancellation()
            // FileHandle creates autoreleased Foundation buffers. Drain them per chunk, not after the entire log.
            let readByteCount = try autoreleasepool {
                let chunk = try handle.read(upToCount: Int(min(UInt64(chunkSize), byteCount - offset))) ?? Data()
                guard !chunk.isEmpty else { throw TranscriptPagingError.sourceChanged }
                chunk.withUnsafeBytes { bytes in
                    for index in bytes.indices where bytes[index] == UInt8(ascii: "\n") {
                        let nextStart = offset + UInt64(index) + 1
                        if nextStart < byteCount { lineStarts.append(nextStart) }
                    }
                }
                return chunk.count
            }
            offset += UInt64(readByteCount)
        }
        return Self(lineStarts: lineStarts, byteCount: byteCount)
    }

    func byteRange(at record: Int) -> Range<UInt64> {
        lineStarts[record]..<(record + 1 < lineStarts.count ? lineStarts[record + 1] : byteCount)
    }

    func readRecord(at record: Int, from handle: FileHandle, maximumByteCount: Int) throws -> Data? {
        let range = byteRange(at: record)
        guard range.count <= maximumByteCount else { return nil }
        try handle.seek(toOffset: range.lowerBound)
        let data = try handle.read(upToCount: range.count) ?? Data()
        guard data.count == range.count else { throw TranscriptPagingError.sourceChanged }
        return data
    }
}
