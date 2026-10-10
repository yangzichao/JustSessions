import Foundation

/// Each reader owns an index and at most three pages. JSON decoding runs on this actor, away from UI updates.
actor TranscriptPageSource {
    let file: URL
    let provider: ConversationProvider
    /// Picks the session out of a database that holds every session, as OpenCode's does.
    let sessionID: String?
    /// Reads a subagent's transcript; see `ClaudeTranscriptReader.includesSidechains`.
    let isSubagentTranscript: Bool
    let limits: TranscriptPageLimits
    /// See `TranscriptBuilder.decodesImages`.
    let decodesImages: Bool
    private var fileIndex: TranscriptFileIndex?
    private var piRecordIndices: [Int]?

    init(
        file: URL,
        provider: ConversationProvider,
        sessionID: String? = nil,
        isSubagentTranscript: Bool = false,
        limits: TranscriptPageLimits = TranscriptPageLimits(),
        decodesImages: Bool = true
    ) {
        self.file = file
        self.provider = provider
        self.sessionID = sessionID
        self.isSubagentTranscript = isSubagentTranscript
        self.limits = limits
        self.decodesImages = decodesImages
    }

    func read(_ request: TranscriptPageRequest, refreshIndex: Bool = false) throws -> TranscriptPage {
        try Task.checkCancellation()
        if provider == .antigravity {
            return try AntigravityTranscriptPageSource.read(file, request: request, limits: limits).preparingMarkdown()
        }
        if provider == .opencode {
            guard let sessionID else { throw OpenCodeDatabaseError.unreadable }
            return try OpenCodeTranscriptPageSource.read(file, sessionID: sessionID, request: request, limits: limits).preparingMarkdown()
        }
        if fileIndex == nil || refreshIndex {
            let updatedIndex = try TranscriptFileIndex.read(file, updating: fileIndex)
            if updatedIndex.fingerprint != fileIndex?.fingerprint { piRecordIndices = nil }
            fileIndex = updatedIndex
        }
        let index = fileIndex!
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        if provider == .pi, piRecordIndices == nil {
            piRecordIndices = try TranscriptPiPageIndex.records(in: index, handle: handle, limits: limits)
        }
        let recordIndices = piRecordIndices
        let recordCount = recordIndices?.count ?? index.lineStarts.count
        let decoder = TranscriptRecordDecoder(
            provider: provider,
            maximumTextLength: limits.maximumTextLength,
            isSubagentTranscript: isSubagentTranscript,
            decodesImages: decodesImages
        )
        return try TranscriptPageReader.read(
            request, recordCount: recordCount, limits: limits,
            sourceID: { recordIndices?[$0] ?? $0 },
            decode: { position in
                let record = recordIndices?[position] ?? position
                return try autoreleasepool {
                    let data = try index.readRecord(at: record, from: handle, maximumByteCount: limits.maximumRecordByteCount)
                    if data == nil, provider == .codex {
                        try handle.seek(toOffset: index.byteRange(at: record).lowerBound)
                        let head = try handle.read(upToCount: 512) ?? Data()
                        if !CodexTranscriptReader.mightContainTranscriptItem(head) { return ([], 0) }
                    }
                    return (decoder.entries(from: data), data?.count ?? 0)
                }
            }
        ).preparingMarkdown()
    }
}
