import Foundation

enum SessionMessageTextReader {
    static let wholeSessionLimits = TranscriptPageLimits(
        targetEntryCount: 5_000, maximumRecordCount: 50_000, targetByteCount: 64 << 20
    )
    static let codexWholeSessionLimits = TranscriptPageLimits(
        targetEntryCount: 256, maximumRecordCount: 4_096, targetByteCount: 8 << 20
    )

    static func wholeSessionLimits(for provider: ConversationProvider) -> TranscriptPageLimits {
        provider == .codex ? codexWholeSessionLimits : wholeSessionLimits
    }

    static func read(_ conversation: Conversation, limits: TranscriptPageLimits? = nil) async throws -> SessionMessageText {
        try await readInFull(
            conversation, keepsResumeState: false, limits: limits ?? wholeSessionLimits(for: conversation.provider)
        ).text
    }

    /// Reads a session whose saved text is older than the session. A Codex session on this Mac resumes from `saved` when
    /// its file has only grown since, and is otherwise read in full; either way the read keeps where the next one can
    /// resume, since a session seen changing is likely to change again. Other providers, and sessions on an SSH host,
    /// are read in full, keeping nothing: rsync replaces a mirrored session's file with a new one at every copy, so it
    /// could never resume.
    static func readChanged(
        _ conversation: Conversation, resuming saved: SessionMessageTextCache.ResumableText?, limits: TranscriptPageLimits? = nil
    ) async throws -> SessionMessageTextRead {
        let limits = limits ?? wholeSessionLimits(for: conversation.provider)
        guard conversation.provider == .codex, conversation.host == .thisMac else {
            return try await readInFull(conversation, keepsResumeState: false, limits: limits)
        }
        if let saved, let resumed = try CodexSessionTextResumer.read(conversation.sourceFile, resuming: saved, limits: limits) {
            return resumed
        }
        return try await readInFull(conversation, keepsResumeState: true, limits: limits)
    }

    static func readInFull(
        _ conversation: Conversation, keepsResumeState: Bool, limits: TranscriptPageLimits
    ) async throws -> SessionMessageTextRead {
        let source = TranscriptPageSource(
            file: conversation.sourceFile, provider: conversation.provider, sessionID: conversation.sessionID, limits: limits,
            decodesImages: false
        )
        var entries: [SessionMessageText.Entry] = []
        var committedEntryCount = 0
        var decodedRecordCount = 0
        var decodedByteCount: UInt64 = 0
        var request = TranscriptPageRequest.first
        var sourceLineage: UUID?
        while true {
            let page = try await source.read(request)
            if request == .first { sourceLineage = page.sourceLineage }
            guard page.sourceLineage == sourceLineage else { throw TranscriptPagingError.sourceChanged }
            committedEntryCount = entries.count
            entries += searchedEntries(in: page)
            decodedRecordCount += page.records.count
            decodedByteCount += UInt64(page.decodedByteCount)
            guard page.hasLater else {
                let index = await source.fileIndex
                let sourceByteCount = decodedByteCount + (index?.scannedByteCount ?? 0)
                let text = SessionMessageText(entries: entries)
                guard keepsResumeState, let index else {
                    return SessionMessageTextRead(
                        text: text, resumeState: nil, resumed: false, decodedRecordCount: decodedRecordCount,
                        sourceByteCount: sourceByteCount
                    )
                }
                let finalPageRecord = page.records.lowerBound
                let state = try CodexSessionTextResumer.state(
                    of: conversation.sourceFile, indexedAs: index.fingerprint, indexedDigest: index.digest,
                    finalPageRecord: finalPageRecord,
                    finalPageByteOffset: finalPageRecord < index.lineStarts.count ? index.lineStarts[finalPageRecord] : index.byteCount,
                    committedEntryCount: committedEntryCount, limits: limits
                )
                return SessionMessageTextRead(
                    text: text, resumeState: state, resumed: false, decodedRecordCount: decodedRecordCount,
                    sourceByteCount: sourceByteCount
                )
            }
            request = .after(page.records.upperBound)
        }
    }

    static func searchedEntries(in page: TranscriptPage) -> [SessionMessageText.Entry] {
        page.entries.compactMap(searchedEntry)
    }

    private static func searchedEntry(_ entry: TranscriptEntry) -> SessionMessageText.Entry? {
        switch entry.content {
        case .userMessage, .assistantMessage, .toolCalls:
            let segments = TranscriptSearchSegments.texts(in: entry)
            return segments.isEmpty ? nil : SessionMessageText.Entry(id: entry.id, segments: segments)
        case .note, .userImage, .toolResultImage:
            return nil
        }
    }
}

struct SessionMessageTextRead: Sendable {
    let text: SessionMessageText
    let resumeState: SessionMessageTextResumeState?
    let resumed: Bool
    let decodedRecordCount: Int
    let sourceByteCount: UInt64
}
