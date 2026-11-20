import Foundation

actor ConversationOutlineReader {
    static func pageLimits(for provider: ConversationProvider) -> TranscriptPageLimits {
        var limits =
            provider.storesSessionsInSQLite
            ? SessionMessageTextReader.wholeSessionLimits
            : TranscriptPageLimits(targetEntryCount: 1_000, maximumRecordCount: 8_192, targetByteCount: 8 << 20)
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
        source = TranscriptPageSource(
            file: conversation.sourceFile, provider: conversation.provider,
            sessionID: conversation.sessionID, isSubagentTranscript: conversation.isSubagent,
            decodesImages: false)
    }

    func hasChanged() -> Bool { !hasRead || ConversationOutlineChangeStamp(of: conversation) != readStamp }

    func update() async throws -> ConversationOutline? {
        let stampBeforeReading = ConversationOutlineChangeStamp(of: conversation)
        let updated: ReadOutline
        do {
            do {
                if conversation.provider == .opencode {
                    let read = try OpenCodeConversationOutline.read(conversation, extending: outline, prefix: openCodePrefix)
                    updated = ReadOutline(outline: read.outline, lineage: nil)
                    openCodePrefix = read.prefix
                } else if let extended = try await extended() {
                    updated = extended
                } else {
                    updated = try await readInFull()
                }
            } catch TranscriptPagingError.sourceChanged {
                updated = try await readInFull()
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            readStamp = stampBeforeReading
            hasRead = true
            throw error
        }
        let isNew = !hasRead || updated.outline.blocks != outline.blocks
        outline = updated.outline
        outlineLineage = updated.lineage
        readStamp = stampBeforeReading
        hasRead = true
        return isNew ? updated.outline : nil
    }

    private func extended() async throws -> ReadOutline? {
        guard !conversation.provider.storesSessionsInSQLite else { return nil }
        guard let resume = ConversationOutlineBuilder.resumePoint(in: outline.blocks) else { return nil }
        let anchor = outline.blocks[resume.keptCount]
        var page = try await source.read(
            .around(TranscriptPageIdentity.entryID(record: resume.record, part: 0)),
            refreshIndex: true, limits: limits, preparesMarkdown: false)
        let lineage = page.sourceLineage
        guard lineage == outlineLineage,
            let first = page.entries.first(where: ConversationOutlineBuilder.makesBlock),
            ConversationOutlineBuilder.startsLike(anchor, first)
        else { return nil }
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

    func latestMessage() async throws -> BookmarkableMessage? {
        var page = try await source.read(.latest, refreshIndex: true, limits: TranscriptPageLimits(), preparesMarkdown: false)
        var pagesBack = 0
        while true {
            if let message = page.entries.reversed().lazy.compactMap(BookmarkableMessage.init).first { return message }
            guard page.hasEarlier, pagesBack < Self.latestMessagePagesBack else { return nil }
            pagesBack += 1
            page = try await source.read(.before(page.records.lowerBound), limits: limits, preparesMarkdown: false)
        }
    }
}
