import Foundation

/// One tab's session, read for its conversation map and for ⌘D in the tab, with the reader's decoder (as
/// TranscriptPagingModel.refresh makes it, TranscriptPagingModel.swift:30-35), without Markdown or images. Keeps the
/// outline it last returned, so a grown file is read again only from its last block's record.
actor ConversationOutlineReader {
    /// File-backed: mid-size pages, so ⌘D waits behind at most one on the shared source. SQLite: whole-session pages,
    /// since each page reopens the database (TranscriptPageSource.swift:47-53; SessionMessageTextReader.swift:13-17).
    /// Tool calls are left unmerged: the builder merges them itself, recording each run's last record.
    static func pageLimits(for provider: ConversationProvider) -> TranscriptPageLimits {
        var limits = switch provider {
        case .opencode, .antigravity: SessionMessageTextReader.wholeSessionLimits
        default: TranscriptPageLimits(targetEntryCount: 1_000, maximumRecordCount: 8_192, targetByteCount: 8 << 20)
        }
        limits.maximumMergedToolCallCount = 0
        return limits
    }
    static let latestMessagePagesBack = 8

    let conversation: Conversation
    private let source: TranscriptPageSource
    private let limits: TranscriptPageLimits
    private var outline = ConversationOutline(blocks: [])
    private var readStamp: ConversationOutlineChangeStamp?
    private var hasRead = false
    private var outlineLineage: UUID?
    private var openCodePrefix: OpenCodeConversationOutline.Prefix?

    private struct ReadOutline {
        let outline: ConversationOutline
        let lineage: UUID?
    }

    init(_ conversation: Conversation) {
        self.conversation = conversation
        limits = Self.pageLimits(for: conversation.provider)
        source = TranscriptPageSource(file: conversation.sourceFile, provider: conversation.provider,
                                      sessionID: conversation.sessionID, isSubagentTranscript: conversation.isSubagent,
                                      decodesImages: false)
    }

    func hasChanged() -> Bool { !hasRead || ConversationOutlineChangeStamp(of: conversation) != readStamp }

    /// The outline after reading what changed; nil when no block changed since the last outline returned.
    func update() async throws -> ConversationOutline? {
        let stamp = ConversationOutlineChangeStamp(of: conversation)   // before reading: anything appended meanwhile shows next check
        let updated: ReadOutline
        do {
            do {
                if conversation.provider == .opencode {
                    let read = try OpenCodeConversationOutline.read(conversation, extending: outline, prefix: openCodePrefix)
                    updated = ReadOutline(outline: read.outline, lineage: nil)
                    openCodePrefix = read.prefix
                } else if let extended = try await extended() { updated = extended } else { updated = try await readInFull() }
            } catch TranscriptPagingError.sourceChanged {
                updated = try await readInFull()   // shrank while its index was scanned (TranscriptFileIndex.swift:55)
            }
        } catch is CancellationError {
            throw CancellationError()   // nothing recorded: the next watch reads again
        } catch {
            readStamp = stamp; hasRead = true   // tried again once the file changes again
            throw error
        }
        let isNew = !hasRead || updated.outline.blocks != outline.blocks
        outline = updated.outline; outlineLineage = updated.lineage; readStamp = stamp; hasRead = true
        return isNew ? updated.outline : nil
    }

    /// Everything from the resume record on, read again: a reply growing in its record, a run still adding calls,
    /// what was appended. Nil, for a read in full, without an outline or when the record read again no longer starts
    /// with its block: a Pi branch left with /tree (the record left the branch, so .around lands past it), a truncated
    /// file (.around lands before it), or a rewritten one.
    private func extended() async throws -> ReadOutline? {
        // Database rows are mutable, including earlier messages. A final anchor cannot prove their prefix unchanged.
        guard conversation.provider != .opencode, conversation.provider != .antigravity else { return nil }
        guard let resume = ConversationOutlineBuilder.resumePoint(in: outline.blocks) else { return nil }
        let anchor = outline.blocks[resume.keptCount]
        var page = try await source.read(.around(TranscriptPageIdentity.entryID(record: resume.record, part: 0)),
                                         refreshIndex: true, limits: limits, preparesMarkdown: false)
        let lineage = page.sourceLineage
        guard lineage == outlineLineage,
              let first = page.entries.first(where: ConversationOutlineBuilder.makesBlock),
              ConversationOutlineBuilder.startsLike(anchor, first) else { return nil }
        var builder = ConversationOutlineBuilder(keeping: outline.blocks[..<resume.keptCount])
        builder.append(page.entries)
        while page.hasLater {
            try Task.checkCancellation()
            page = try await source.read(.after(page.records.upperBound), limits: limits, preparesMarkdown: false)
            guard page.sourceLineage == lineage else { throw TranscriptPagingError.sourceChanged }
            builder.append(page.entries)
        }
        return ReadOutline(outline: ConversationOutline(blocks: builder.blocks), lineage: lineage)
    }

    private func readInFull() async throws -> ReadOutline {
        var builder = ConversationOutlineBuilder()
        var page = try await source.read(.first, refreshIndex: true, limits: limits, preparesMarkdown: false)
        let lineage = page.sourceLineage
        builder.append(page.entries)
        while page.hasLater {
            try Task.checkCancellation()
            page = try await source.read(.after(page.records.upperBound), limits: limits, preparesMarkdown: false)
            guard page.sourceLineage == lineage else { throw TranscriptPagingError.sourceChanged }
            builder.append(page.entries)
        }
        return ReadOutline(outline: ConversationOutline(blocks: builder.blocks), lineage: lineage)
    }

    /// ⌘D in the tab (TRM-74): the newest of your messages or the CLI's replies in the file now. The reader's last page
    /// first, then up to `latestMessagePagesBack` outline-size pages back. Nil when none is found.
    func latestMessage() async throws -> TranscriptEntry? {
        var page = try await source.read(.latest, refreshIndex: true, limits: TranscriptPageLimits(), preparesMarkdown: false)
        var pagesBack = 0
        while true {
            if let message = page.entries.last(where: { MessageBookmark.Kind($0.content) != nil }) { return message }
            guard page.hasEarlier, pagesBack < Self.latestMessagePagesBack else { return nil }
            pagesBack += 1
            page = try await source.read(.before(page.records.lowerBound), limits: limits, preparesMarkdown: false)
        }
    }
}
