import Foundation

/// One session as the conversation map draws it (TAB-10): a block per message, run of tool calls, or attached image,
/// in conversation order. In memory only (PERF-89). A message's `entryID` is the reader's paged ID
/// (`TranscriptPageIdentity`), which its bookmark keeps; a tool run's is its first entry's, an anchor only.
struct ConversationOutline: Sendable, Equatable {
    struct Block: Sendable, Equatable {
        enum Kind: Sendable, Equatable {
            case user, assistant, toolRun, image

            init?(_ content: TranscriptEntry.Content) {
                switch content {
                case .userMessage: self = .user
                case .assistantMessage: self = .assistant
                case .toolCalls, .toolResultImage: self = .toolRun
                case .userImage: self = .image
                case .note: return nil
                }
            }
        }

        let entryID: Int
        /// The source record of the block's last entry, so an update re-reads from a record no kept block reaches into.
        var lastRecord: Int
        let kind: Kind
        let timestamp: Date?
        /// At most 80 characters: the bookmark snippet of a message's head, or a run's first summary.
        var snippet: String
        /// Each line's length in map columns (0 = blank row inside), ≤ 24 for a message, ≤ 4 for a run.
        var lineWidths: [UInt8]
        var toolCallCount: Int

        var record: Int { TranscriptPageIdentity.record(for: entryID) }
        var isMessage: Bool { kind == .user || kind == .assistant }
        var isYours: Bool { kind == .user || kind == .image }
    }

    let blocks: [Block]
    /// Each block's first row: its lines are rows, and one blank row comes before a block whose side changed.
    let rowStarts: [Int]
    let rowCount: Int
    let messageCount: Int
    /// Set by `ConversationOutlineModel` when it publishes, rising across relinks, so the Canvas compares one number.
    var revision = 0

    init(blocks: [Block]) {
        var starts: [Int] = []
        var row = 0
        var messages = 0
        starts.reserveCapacity(blocks.count)
        for (index, block) in blocks.enumerated() {
            if index > 0, blocks[index - 1].isYours != block.isYours { row += 1 }
            starts.append(row)
            row += max(1, block.lineWidths.count)
            if block.isMessage { messages += 1 }
        }
        self.blocks = blocks
        rowStarts = starts
        rowCount = row
        messageCount = messages
    }

    /// The block holding `row`: the last starting at or before it (binary search on rowStarts); nil when empty.
    func blockIndex(atRow row: Int) -> Int? {
        var lower = 0
        var upper = rowStarts.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if rowStarts[middle] <= row { lower = middle + 1 } else { upper = middle }
        }
        return lower > 0 ? lower - 1 : nil
    }

    /// A bookmark's block: its exact entry ID (binary search; IDs ascend), else a block in its record, each matched by
    /// kind and snippet head as `MessageBookmarkNavigation.locate` follows a moved part (MessageBookmarkNavigation.swift:
    /// 44-47). A head that changed since keeps a chip: its ID by kind alone, else its record's first block of its kind.
    /// Nil when its message is gone or newer than the last read.
    func blockIndex(for bookmark: MessageBookmark) -> Int? {
        let kind: Block.Kind = bookmark.kind == .user ? .user : .assistant
        let head = bookmark.snippet.prefix(40).lowercased()
        let record = TranscriptPageIdentity.record(for: bookmark.entryID)
        let exact = firstBlockIndex(atOrAfter: bookmark.entryID)
        let exactKind = exact < blocks.count && blocks[exact].entryID == bookmark.entryID && blocks[exact].kind == kind
        if exactKind, blocks[exact].snippet.lowercased().hasPrefix(head) { return exact }
        let first = firstBlockIndex(atOrAfter: TranscriptPageIdentity.entryID(record: record, part: 0))
        let inRecord = blocks[first...].prefix { $0.record == record }.indices.filter { blocks[$0].kind == kind }
        return inRecord.first { blocks[$0].snippet.lowercased().hasPrefix(head) } ?? (exactKind ? exact : inRecord.first)
    }

    /// What a click on block `index` opens: a message's or image's own ID; for a tool run the message before it, or after.
    func targetEntryID(forBlockAt index: Int) -> Int? {
        if blocks[index].kind != .toolRun { return blocks[index].entryID }
        return blocks[..<index].last(where: \.isMessage)?.entryID ?? blocks[(index + 1)...].first(where: \.isMessage)?.entryID
    }

    private func firstBlockIndex(atOrAfter entryID: Int) -> Int {
        var lower = 0
        var upper = blocks.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if blocks[middle].entryID < entryID { lower = middle + 1 } else { upper = middle }
        }
        return lower
    }
}
