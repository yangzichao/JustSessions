import Foundation

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
        var lastRecord: Int
        let kind: Kind
        let timestamp: Date?
        var snippet: String
        var lineWidths: [UInt8]
        var toolCallCount: Int

        var record: Int { TranscriptPageIdentity.record(for: entryID) }
        var isMessage: Bool { kind == .user || kind == .assistant }
        var isYours: Bool { kind == .user || kind == .image }
    }

    let blocks: [Block]
    let rowStarts: [Int]
    let rowCount: Int
    let messageCount: Int
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

    func blockIndex(atRow row: Int) -> Int? {
        var lower = 0
        var upper = rowStarts.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if rowStarts[middle] <= row { lower = middle + 1 } else { upper = middle }
        }
        return lower > 0 ? lower - 1 : nil
    }

    func blockIndex(for bookmark: MessageBookmark) -> Int? {
        let kind: Block.Kind = bookmark.kind == .user ? .user : .assistant
        func stillStartsLikeBookmark(_ index: Int) -> Bool {
            MessageBookmarkNavigation.snippet(blocks[index].snippet, stillStartsLike: bookmark.snippet)
        }
        let record = TranscriptPageIdentity.record(for: bookmark.entryID)
        let exact = firstBlockIndex(atOrAfter: bookmark.entryID)
        let exactKind = exact < blocks.count && blocks[exact].entryID == bookmark.entryID && blocks[exact].kind == kind
        if exactKind, stillStartsLikeBookmark(exact) { return exact }
        let first = firstBlockIndex(atOrAfter: TranscriptPageIdentity.entryID(record: record, part: 0))
        let inRecord = blocks[first...].prefix { $0.record == record }.indices.filter { blocks[$0].kind == kind }
        return inRecord.first(where: stillStartsLikeBookmark) ?? (exactKind ? exact : inRecord.first)
    }

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
