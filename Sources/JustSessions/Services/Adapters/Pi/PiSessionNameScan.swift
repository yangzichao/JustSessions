import Foundation

/// The last name a Pi session was given with `/name` or `--name`. Pi writes a name once, as a `session_info` line, so
/// in a long session it can sit megabytes before the end. A scan reads on from where the previous one stopped, once
/// the bytes it ended on are still in place there, so a refresh reads only what Pi wrote since.
struct PiSessionNameScan: Codable, Equatable, Sendable {
    let latestName: String?
    let scannedByteCount: Int
    let endingBytes: Data

    static let defaultChunkSize = 1 << 20
    static let maximumNameLineByteCount = 65_536
    private static let endingByteCount = 256
    private static let marker = Data(#""session_info""#.utf8)
    private static let newline = UInt8(ascii: "\n")

    static func scan(_ file: URL, continuing previous: PiSessionNameScan?, chunkSize: Int = defaultChunkSize) -> PiSessionNameScan? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let resumed = previous.flatMap { $0.isStillInPlace(in: handle) ? $0 : nil }
        var latestName = resumed?.latestName
        var scannedByteCount = resumed?.scannedByteCount ?? 0
        var readByteCount = scannedByteCount
        var unfinishedLine = Data()
        var isSkippingLongLine = false
        do {
            try handle.seek(toOffset: UInt64(readByteCount))
            while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
                let buffer = unfinishedLine + chunk
                let bufferStart = readByteCount - unfinishedLine.count
                readByteCount += chunk.count
                var unfinishedStart = 0
                buffer.withUnsafeBytes { bytes in
                    var start = 0
                    if isSkippingLongLine {
                        guard let lineEnd = firstIndex(of: newline, in: bytes, from: 0) else {
                            unfinishedStart = bytes.count
                            return
                        }
                        isSkippingLongLine = false
                        start = lineEnd + 1
                        scannedByteCount = bufferStart + start
                    }
                    guard let lastNewline = lastIndex(of: newline, in: bytes, from: start) else {
                        unfinishedStart = start
                        return
                    }
                    if let name = latestNameInLines(of: bytes, from: start, through: lastNewline) { latestName = name }
                    scannedByteCount = bufferStart + lastNewline + 1
                    unfinishedStart = lastNewline + 1
                }
                if isSkippingLongLine || buffer.count - unfinishedStart > maximumNameLineByteCount {
                    isSkippingLongLine = true
                    unfinishedLine = Data()
                } else {
                    unfinishedLine = buffer.subdata(in: unfinishedStart..<buffer.count)
                }
            }
            let endingStart = max(0, scannedByteCount - endingByteCount)
            try handle.seek(toOffset: UInt64(endingStart))
            let endingBytes = try handle.read(upToCount: scannedByteCount - endingStart) ?? Data()
            return PiSessionNameScan(latestName: latestName, scannedByteCount: scannedByteCount, endingBytes: endingBytes)
        } catch {
            return nil
        }
    }

    private func isStillInPlace(in handle: FileHandle) -> Bool {
        guard scannedByteCount > 0 else { return true }
        guard endingBytes.count <= scannedByteCount, endingBytes.last == Self.newline else { return false }
        do {
            try handle.seek(toOffset: UInt64(scannedByteCount - endingBytes.count))
            return try handle.read(upToCount: endingBytes.count) == endingBytes
        } catch {
            return false
        }
    }

    private static func latestNameInLines(of bytes: UnsafeRawBufferPointer, from start: Int, through end: Int) -> String? {
        guard let base = bytes.baseAddress else { return nil }
        var latestName: String?
        var searchStart = start
        while searchStart < end,
            let found = marker.withUnsafeBytes({ markerBytes in
                memmem(base + searchStart, end - searchStart, markerBytes.baseAddress, markerBytes.count)
            })
        {
            let hit = base.distance(to: UnsafeRawPointer(found))
            let lineStart = (lastIndex(of: newline, in: bytes, from: start, before: hit) ?? start - 1) + 1
            let lineEnd = firstIndex(of: newline, in: bytes, from: hit) ?? end
            let line = Data(bytes: base + lineStart, count: lineEnd - lineStart)
            if let name = PiSessionTitle.latestName(amongLines: [line]) { latestName = name }
            searchStart = lineEnd + 1
        }
        return latestName
    }

    private static func firstIndex(of byte: UInt8, in bytes: UnsafeRawBufferPointer, from start: Int) -> Int? {
        guard let base = bytes.baseAddress, start < bytes.count,
            let found = memchr(base + start, Int32(byte), bytes.count - start)
        else { return nil }
        return base.distance(to: UnsafeRawPointer(found))
    }

    private static func lastIndex(of byte: UInt8, in bytes: UnsafeRawBufferPointer, from start: Int, before limit: Int? = nil) -> Int? {
        var index = (limit ?? bytes.count) - 1
        while index >= start {
            if bytes[index] == byte { return index }
            index -= 1
        }
        return nil
    }
}
