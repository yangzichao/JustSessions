import Darwin
import Foundation

struct SessionMessageTextResumeState: Sendable, Codable, Equatable {
    let device: Int32
    let inode: UInt64
    let byteCount: UInt64
    let digest: Data
    let finalPageRecord: Int
    let finalPageByteOffset: UInt64
    let committedEntryCount: Int
    let pageLimits: [Int]

    static func pageLimits(of limits: TranscriptPageLimits) -> [Int] {
        [
            limits.targetEntryCount, limits.maximumRecordCount, limits.targetByteCount, limits.maximumRecordByteCount,
            limits.maximumTextLength,
        ]
    }

    func isConsistent(with text: SessionMessageText) -> Bool {
        guard digest.count == CRC32Checksum.byteCount, finalPageRecord >= 0, finalPageByteOffset <= byteCount,
            (0...text.entries.count).contains(committedEntryCount)
        else { return false }
        let committedLast = text.entries[..<committedEntryCount].last.map { TranscriptPageIdentity.record(for: $0.id) }
        let finalPageFirst = text.entries[committedEntryCount...].first.map { TranscriptPageIdentity.record(for: $0.id) }
        return (committedLast ?? -1) < finalPageRecord && (finalPageFirst ?? finalPageRecord) >= finalPageRecord
    }
}

enum CodexSessionTextResumer {
    static let maximumResumedByteCount: UInt64 = 64 << 20
    private static let hashChunkByteCount = 1 << 20

    static func read(
        _ file: URL, resuming saved: SessionMessageTextCache.ResumableText, limits: TranscriptPageLimits
    ) throws -> SessionMessageTextRead? {
        let state = saved.state
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let fingerprint = try TranscriptFileFingerprint(handle: handle)
        let byteCount = fingerprint.byteCount
        let resumeOffset = state.finalPageByteOffset
        guard state.pageLimits == SessionMessageTextResumeState.pageLimits(of: limits),
            fingerprint.device == state.device, fingerprint.inode == state.inode, byteCount > state.byteCount,
            resumeOffset <= state.byteCount, byteCount - resumeOffset <= maximumResumedByteCount
        else { return nil }

        let descriptor = handle.fileDescriptor
        let tail = try bytes(of: descriptor, from: resumeOffset, count: Int(byteCount - resumeOffset))
        var hasher = CRC32Checksum()
        try hash(descriptor, upTo: resumeOffset, into: &hasher)
        var savedBytesHasher = hasher
        tail.withUnsafeBytes {
            savedBytesHasher.update(bufferPointer: UnsafeRawBufferPointer(rebasing: $0[..<Int(state.byteCount - resumeOffset)]))
        }
        guard savedBytesHasher.finalize() == state.digest else { return nil }
        tail.withUnsafeBytes { hasher.update(bufferPointer: $0) }

        let recordStarts = recordStarts(in: tail)
        let firstRecord = state.finalPageRecord
        let decoder = TranscriptRecordDecoder(provider: .codex, maximumTextLength: limits.maximumTextLength, decodesImages: false)
        var entries = Array(saved.text.entries[..<state.committedEntryCount])
        var committedEntryCount = entries.count
        var finalPageRecord = firstRecord
        var decodedRecordCount = 0
        var request = TranscriptPageRequest.after(firstRecord)
        while true {
            let page = try TranscriptPageReader.read(
                request, recordCount: firstRecord + recordStarts.count, limits: limits, sourceID: { $0 },
                decode: { position in
                    guard position >= firstRecord else { return ([], 0) }
                    let tailRecord = position - firstRecord
                    let range = recordStarts[tailRecord]..<(tailRecord + 1 < recordStarts.count ? recordStarts[tailRecord + 1] : tail.count)
                    return autoreleasepool {
                        let data = range.count <= limits.maximumRecordByteCount ? Data(tail[range]) : nil
                        return decoder.pageEntries(from: data) { Data(tail[range.prefix($0)]) }
                    }
                }
            ).preparingMarkdown()
            finalPageRecord = page.records.lowerBound
            committedEntryCount = entries.count
            entries += SessionMessageTextReader.searchedEntries(in: page)
            decodedRecordCount += page.records.count
            guard page.hasLater else { break }
            request = .after(page.records.upperBound)
        }
        guard try TranscriptFileFingerprint(handle: handle).byteCount >= byteCount else { throw TranscriptPagingError.sourceChanged }
        let resumeState = SessionMessageTextResumeState(
            device: fingerprint.device, inode: fingerprint.inode, byteCount: byteCount, digest: hasher.finalize(),
            finalPageRecord: finalPageRecord,
            finalPageByteOffset: resumeOffset + UInt64(recordStarts[finalPageRecord - firstRecord]),
            committedEntryCount: committedEntryCount, pageLimits: state.pageLimits
        )
        return SessionMessageTextRead(
            text: SessionMessageText(entries: entries), resumeState: resumeState, resumed: true,
            decodedRecordCount: decodedRecordCount, sourceByteCount: byteCount
        )
    }

    static func state(
        of file: URL, indexedAs indexFingerprint: TranscriptFileFingerprint, indexedDigest: Data? = nil,
        finalPageRecord: Int, finalPageByteOffset: UInt64,
        committedEntryCount: Int, limits: TranscriptPageLimits
    ) throws -> SessionMessageTextResumeState? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let digest: Data
        if let indexedDigest {
            guard indexedDigest.count == CRC32Checksum.byteCount else { return nil }
            digest = indexedDigest
        } else {
            var hasher = CRC32Checksum()
            do {
                try hash(handle.fileDescriptor, upTo: indexFingerprint.byteCount, into: &hasher)
            } catch TranscriptPagingError.sourceChanged {
                return nil
            }
            digest = hasher.finalize()
        }
        guard (try? TranscriptFileFingerprint(handle: handle)) == indexFingerprint else { return nil }
        return SessionMessageTextResumeState(
            device: indexFingerprint.device, inode: indexFingerprint.inode, byteCount: indexFingerprint.byteCount,
            digest: digest, finalPageRecord: finalPageRecord, finalPageByteOffset: finalPageByteOffset,
            committedEntryCount: committedEntryCount, pageLimits: SessionMessageTextResumeState.pageLimits(of: limits)
        )
    }

    private static func recordStarts(in bytes: [UInt8]) -> [Int] {
        guard !bytes.isEmpty else { return [] }
        var starts = [0]
        bytes.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count, let newline = memchr(base + offset, Int32(UInt8(ascii: "\n")), buffer.count - offset) {
                offset = base.distance(to: UnsafeRawPointer(newline)) + 1
                if offset < buffer.count { starts.append(offset) }
            }
        }
        return starts
    }

    private static func bytes(of descriptor: Int32, from offset: UInt64, count: Int) throws -> [UInt8] {
        try [UInt8](unsafeUninitializedCapacity: count) { buffer, initializedCount in
            try read(descriptor, from: offset, into: UnsafeMutableRawBufferPointer(buffer))
            initializedCount = count
        }
    }

    private static func hash(_ descriptor: Int32, upTo byteCount: UInt64, into hasher: inout CRC32Checksum) throws {
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: hashChunkByteCount, alignment: 1)
        defer { buffer.deallocate() }
        var offset: UInt64 = 0
        while offset < byteCount {
            try Task.checkCancellation()
            let chunk = UnsafeMutableRawBufferPointer(rebasing: buffer[..<Int(min(UInt64(buffer.count), byteCount - offset))])
            try read(descriptor, from: offset, into: chunk)
            hasher.update(bufferPointer: UnsafeRawBufferPointer(chunk))
            offset += UInt64(chunk.count)
        }
    }

    private static func read(_ descriptor: Int32, from offset: UInt64, into buffer: UnsafeMutableRawBufferPointer) throws {
        var filled = 0
        while filled < buffer.count {
            let count = pread(descriptor, buffer.baseAddress! + filled, buffer.count - filled, off_t(offset) + off_t(filled))
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { throw TranscriptPagingError.sourceChanged }
            filled += count
        }
    }
}
