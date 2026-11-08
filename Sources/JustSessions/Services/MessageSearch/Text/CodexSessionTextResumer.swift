import CryptoKit
import Darwin
import Foundation

/// Where a Codex session's saved search text can resume once the CLI appends: the bytes the text came from, and the
/// start of its final page, the only page an append can change. The digest covers every one of those bytes, so a file
/// that grew after an earlier record changed is read in full, as is one replaced, truncated, or rewritten.
struct SessionMessageTextResumeState: Sendable, Codable, Equatable {
    let device: Int32
    let inode: UInt64
    /// How many bytes of the file the text came from.
    let byteCount: UInt64
    /// SHA-256 of the first `byteCount` bytes.
    let digest: Data
    /// The final page's first record, read again on resume.
    let finalPageRecord: Int
    /// Where `finalPageRecord` starts in the file.
    let finalPageByteOffset: UInt64
    /// How many of the text's entries come from records before `finalPageRecord`.
    let committedEntryCount: Int
    /// The page limits the text was read with. Where pages end decides which tool calls merge into one entry, so text
    /// read with other limits is never resumed from, even if they changed without a new cache format.
    let pageLimits: [Int]

    static func pageLimits(of limits: TranscriptPageLimits) -> [Int] {
        [limits.targetEntryCount, limits.maximumRecordCount, limits.targetByteCount, limits.maximumRecordByteCount,
         limits.maximumTextLength]
    }

    /// Whether this state could have been saved with `text`; a saved file that fails this is read in full again.
    func isConsistent(with text: SessionMessageText) -> Bool {
        guard digest.count == SHA256.byteCount, finalPageRecord >= 0, finalPageByteOffset <= byteCount,
              (0...text.entries.count).contains(committedEntryCount) else { return false }
        let committedLast = text.entries[..<committedEntryCount].last.map { TranscriptPageIdentity.record(for: $0.id) }
        let finalPageFirst = text.entries[committedEntryCount...].first.map { TranscriptPageIdentity.record(for: $0.id) }
        return (committedLast ?? -1) < finalPageRecord && (finalPageFirst ?? finalPageRecord) >= finalPageRecord
    }
}

/// Reads a grown Codex session from its saved final page on, after checking that every byte saved text came from is
/// unchanged. Every byte is read once: the bytes before the final page are only hashed, and the rest, read into
/// memory, is both hashed and parsed, so the saved digest and the parsed records describe the same bytes even while the
/// CLI writes.
enum CodexSessionTextResumer {
    /// The most bytes from the final page's start to the file's end a resume holds in memory; past this the session is
    /// read in full.
    static let maximumResumedByteCount: UInt64 = 64 << 20
    private static let hashChunkByteCount = 1 << 20

    /// Nil when `saved` can't be resumed from, as when the file was replaced, didn't grow, or changed before its end;
    /// the session is then read in full.
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
              resumeOffset <= state.byteCount, byteCount - resumeOffset <= maximumResumedByteCount else { return nil }

        let descriptor = handle.fileDescriptor
        let tail = try bytes(of: descriptor, from: resumeOffset, count: Int(byteCount - resumeOffset))
        var hasher = SHA256()
        try hash(descriptor, upTo: resumeOffset, into: &hasher)
        var savedBytesHasher = hasher
        tail.withUnsafeBytes { savedBytesHasher.update(bufferPointer: UnsafeRawBufferPointer(rebasing: $0[..<Int(state.byteCount - resumeOffset)])) }
        guard Data(savedBytesHasher.finalize()) == state.digest else { return nil }
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
                    // Earlier records are only decoded for the speaker before a page, which search text doesn't use.
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
        // A running CLI appends while the read runs; only a file that shrank fails it, as `TranscriptFileIndex` does.
        guard try TranscriptFileFingerprint(handle: handle).byteCount >= byteCount else { throw TranscriptPagingError.sourceChanged }
        let resumeState = SessionMessageTextResumeState(
            device: fingerprint.device, inode: fingerprint.inode, byteCount: byteCount, digest: Data(hasher.finalize()),
            finalPageRecord: finalPageRecord,
            finalPageByteOffset: resumeOffset + UInt64(recordStarts[finalPageRecord - firstRecord]),
            committedEntryCount: committedEntryCount, pageLimits: state.pageLimits
        )
        return SessionMessageTextRead(
            text: SessionMessageText(entries: entries), resumeState: resumeState, resumed: true,
            decodedRecordCount: decodedRecordCount, sourceByteCount: byteCount
        )
    }

    /// The resume state after a full read whose index is `indexFingerprint`, reusing its digest when provided. Nil
    /// when the file changed in any way since it was indexed, as the text may then come from other bytes than these;
    /// the next change reads it in full again.
    static func state(
        of file: URL, indexedAs indexFingerprint: TranscriptFileFingerprint, indexedDigest: Data? = nil,
        finalPageRecord: Int, finalPageByteOffset: UInt64,
        committedEntryCount: Int, limits: TranscriptPageLimits
    ) throws -> SessionMessageTextResumeState? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let digest: Data
        if let indexedDigest {
            guard indexedDigest.count == SHA256.byteCount else { return nil }
            digest = indexedDigest
        } else {
            var hasher = SHA256()
            do {
                try hash(handle.fileDescriptor, upTo: indexFingerprint.byteCount, into: &hasher)
            } catch TranscriptPagingError.sourceChanged {
                return nil
            }
            digest = Data(hasher.finalize())
        }
        guard (try? TranscriptFileFingerprint(handle: handle)) == indexFingerprint else { return nil }
        return SessionMessageTextResumeState(
            device: indexFingerprint.device, inode: indexFingerprint.inode, byteCount: indexFingerprint.byteCount,
            digest: digest, finalPageRecord: finalPageRecord, finalPageByteOffset: finalPageByteOffset,
            committedEntryCount: committedEntryCount, pageLimits: SessionMessageTextResumeState.pageLimits(of: limits)
        )
    }

    /// Where each record starts in `bytes`, as `TranscriptFileIndex` splits a file: a record runs through its newline,
    /// the last may have none, and nothing after a final newline is a record.
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

    /// Hashes the first `byteCount` bytes in chunks through one buffer.
    private static func hash(_ descriptor: Int32, upTo byteCount: UInt64, into hasher: inout SHA256) throws {
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

    /// Fills `buffer` from `offset`; a file that ends first has shrunk since its size was read.
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
