import Foundation

/// Each reader owns an index and at most three pages. JSON decoding runs on this actor, away from UI updates.
actor TranscriptPageSource {
    let file: URL
    let provider: ConversationProvider
    let limits: TranscriptPageLimits
    private var fileIndex: TranscriptFileIndex?
    private var piRecordIndices: [Int]?

    init(file: URL, provider: ConversationProvider, limits: TranscriptPageLimits = TranscriptPageLimits()) {
        self.file = file
        self.provider = provider
        self.limits = limits
    }

    func read(_ request: TranscriptPageRequest, refreshIndex: Bool = false) throws -> TranscriptPage {
        try Task.checkCancellation()
        if provider == .antigravity {
            return try AntigravityTranscriptPageSource.read(file, request: request, limits: limits)
        }
        if fileIndex == nil || refreshIndex {
            fileIndex = try TranscriptFileIndex.read(file)
            piRecordIndices = nil
        }
        let index = fileIndex!
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        if provider == .pi, piRecordIndices == nil {
            piRecordIndices = try TranscriptPiPageIndex.records(in: index, handle: handle, limits: limits)
        }
        let recordIndices = piRecordIndices
        let recordCount = recordIndices?.count ?? index.lineStarts.count
        let decoder = TranscriptRecordDecoder(provider: provider, maximumTextLength: limits.maximumTextLength)
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
        )
    }
}
