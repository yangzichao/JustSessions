import Foundation

/// Only byte offsets are retained, never JSON objects or message text. A 100,000-line log needs about 0.8 MiB.
struct TranscriptFileIndex: Sendable {
    let lineStarts: [UInt64]
    let byteCount: UInt64
    let fingerprint: TranscriptFileFingerprint
    /// Work performed by this update, excluding the bounded append validation reads.
    let scannedByteCount: UInt64
    private let prefix: Data
    private let suffix: Data

    static func read(_ file: URL, chunkSize: Int = 1 << 20, updating previous: Self? = nil) throws -> Self {
        precondition(chunkSize > 0)
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let fingerprint = try TranscriptFileFingerprint(handle: handle)
        let byteCount = fingerprint.byteCount
        if let previous, fingerprint == previous.fingerprint {
            return Self(lineStarts: previous.lineStarts, byteCount: byteCount, fingerprint: fingerprint,
                        scannedByteCount: 0, prefix: previous.prefix, suffix: previous.suffix)
        }
        let appending = try previous.map {
            try fingerprint.identifiesSameFile(as: $0.fingerprint) && byteCount > $0.byteCount
                && matchesPreviousEdges($0, in: handle)
        } ?? false
        var lineStarts = appending ? previous!.lineStarts : (byteCount == 0 ? [] : [0])
        var offset: UInt64 = appending ? previous!.byteCount : 0
        let scanStart = offset
        if appending, previous!.byteCount == 0 || previous!.suffix.last == UInt8(ascii: "\n") {
            lineStarts.append(offset)
        }
        try handle.seek(toOffset: offset)
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
        let edgeLength = min(byteCount, 256)
        let prefix = try edge(in: handle, offset: 0, count: edgeLength)
        let suffix = try edge(in: handle, offset: byteCount - edgeLength, count: edgeLength)
        guard try TranscriptFileFingerprint(handle: handle) == fingerprint else { throw TranscriptPagingError.sourceChanged }
        return Self(lineStarts: lineStarts, byteCount: byteCount, fingerprint: fingerprint,
                    scannedByteCount: byteCount - scanStart, prefix: prefix, suffix: suffix)
    }

    /// Detect truncation/rewrite followed by growth at the boundaries, including completion of a partial final line.
    private static func matchesPreviousEdges(_ previous: Self, in handle: FileHandle) throws -> Bool {
        let prefix = try edge(in: handle, offset: 0, count: UInt64(previous.prefix.count))
        let suffix = try edge(in: handle, offset: previous.byteCount - UInt64(previous.suffix.count), count: UInt64(previous.suffix.count))
        return prefix == previous.prefix && suffix == previous.suffix
    }

    private static func edge(in handle: FileHandle, offset: UInt64, count: UInt64) throws -> Data {
        try handle.seek(toOffset: offset)
        return try handle.read(upToCount: Int(count)) ?? Data()
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
