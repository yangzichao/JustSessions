import Foundation

struct TranscriptFileIndex: Sendable {
    let lineStarts: [UInt64]
    let byteCount: UInt64
    let fingerprint: TranscriptFileFingerprint
    let scannedByteCount: UInt64
    let validatedByteCount: UInt64
    let contentLineage: UUID
    let digest: Data
    private let lastByte: UInt8?

    static func read(_ file: URL, chunkSize: Int = 1 << 20, updating previous: Self? = nil) throws -> Self {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        return try read(handle, chunkSize: chunkSize, updating: previous)
    }

    static func read(_ handle: FileHandle, chunkSize: Int = 1 << 20, updating previous: Self? = nil) throws -> Self {
        precondition(chunkSize > 0)
        let fingerprint = try TranscriptFileFingerprint(handle: handle)
        let byteCount = fingerprint.byteCount
        if let previous, fingerprint == previous.fingerprint {
            return Self(
                lineStarts: previous.lineStarts, byteCount: byteCount, fingerprint: fingerprint,
                scannedByteCount: 0, validatedByteCount: 0, contentLineage: previous.contentLineage,
                digest: previous.digest, lastByte: previous.lastByte)
        }
        var hasher = CRC32Checksum()
        var validatedByteCount: UInt64 = 0
        var appending = false
        if let previous, byteCount >= previous.byteCount {
            try handle.seek(toOffset: 0)
            while validatedByteCount < previous.byteCount {
                try Task.checkCancellation()
                let count = try autoreleasepool {
                    let chunk = try handle.read(upToCount: Int(min(UInt64(chunkSize), previous.byteCount - validatedByteCount))) ?? Data()
                    guard !chunk.isEmpty else { throw TranscriptPagingError.sourceChanged }
                    hasher.update(data: chunk)
                    return chunk.count
                }
                validatedByteCount += UInt64(count)
            }
            let prefixHasher = hasher
            appending = prefixHasher.finalize() == previous.digest
        }
        if !appending { hasher = CRC32Checksum() }
        var lineStarts = appending ? previous!.lineStarts : (byteCount == 0 ? [] : [0])
        var offset: UInt64 = appending ? previous!.byteCount : 0
        var lastByte = appending ? previous!.lastByte : nil
        let scanStart = offset
        if appending, offset < byteCount, previous!.byteCount == 0 || previous!.lastByte == UInt8(ascii: "\n") {
            lineStarts.append(offset)
        }
        try handle.seek(toOffset: offset)
        while offset < byteCount {
            try Task.checkCancellation()
            // FileHandle creates autoreleased Foundation buffers. Drain them per chunk, not after the entire log.
            let readByteCount = try autoreleasepool {
                let chunk = try handle.read(upToCount: Int(min(UInt64(chunkSize), byteCount - offset))) ?? Data()
                guard !chunk.isEmpty else { throw TranscriptPagingError.sourceChanged }
                hasher.update(data: chunk)
                lastByte = chunk.last
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
        guard try TranscriptFileFingerprint(handle: handle).byteCount >= byteCount else { throw TranscriptPagingError.sourceChanged }
        return Self(
            lineStarts: lineStarts, byteCount: byteCount, fingerprint: fingerprint,
            scannedByteCount: byteCount - scanStart, validatedByteCount: validatedByteCount,
            contentLineage: appending ? previous!.contentLineage : UUID(), digest: hasher.finalize(), lastByte: lastByte)
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
