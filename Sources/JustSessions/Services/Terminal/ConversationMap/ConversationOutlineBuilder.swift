import Foundation

struct ConversationOutlineBuilder {
    static let columns = 80
    static let maximumLinesPerMessage = 24
    static let maximumLinesPerToolRun = 4
    static let snippetSourceLength = 400
    private static let maximumUTF8BytesPerScalar = 4
    typealias Block = ConversationOutline.Block

    private(set) var blocks: [Block]

    init(keeping prefix: ArraySlice<Block> = []) { blocks = Array(prefix) }

    mutating func append(_ entries: [TranscriptEntry]) {
        for entry in entries {
            let record = TranscriptPageIdentity.record(for: entry.id)
            switch entry.content {
            case .userMessage(let text): appendMessage(.user, text, entry, record)
            case .assistantMessage(let text): appendMessage(.assistant, text, entry, record)
            case .toolCalls(let summaries): appendToolCalls(summaries, entry, record)
            case .toolResultImage: appendToolCalls([], entry, record)
            case .userImage:
                blocks.append(
                    Block(
                        entryID: entry.id, lastRecord: record, kind: .image, timestamp: entry.timestamp,
                        snippet: "", lineWidths: [12], toolCallCount: 0))
            case .note: continue
            }
        }
    }

    private mutating func appendMessage(_ kind: Block.Kind, _ text: String, _ entry: TranscriptEntry, _ record: Int) {
        blocks.append(
            Block(
                entryID: entry.id, lastRecord: record, kind: kind, timestamp: entry.timestamp,
                snippet: Self.snippet(of: entry),
                lineWidths: Self.lineWidthsCountingUTF8LeadBytes(of: text, maximumLines: Self.maximumLinesPerMessage),
                toolCallCount: 0))
    }

    private mutating func appendToolCalls(_ summaries: [String], _ entry: TranscriptEntry, _ record: Int) {
        let widths = summaries.prefix(Self.maximumLinesPerToolRun).map { UInt8($0.prefix(Self.columns).count) }
        if let last = blocks.indices.last, blocks[last].kind == .toolRun {
            blocks[last].toolCallCount += summaries.count
            blocks[last].lastRecord = record
            blocks[last].lineWidths = Array((blocks[last].lineWidths + widths).prefix(Self.maximumLinesPerToolRun))
            if blocks[last].snippet.isEmpty { blocks[last].snippet = Self.toolRunSnippet(of: summaries) }
        } else {
            blocks.append(
                Block(
                    entryID: entry.id, lastRecord: record, kind: .toolRun, timestamp: entry.timestamp,
                    snippet: Self.toolRunSnippet(of: summaries),
                    lineWidths: widths.isEmpty ? [8] : widths, toolCallCount: summaries.count))
        }
    }

    private static func toolRunSnippet(of summaries: [String]) -> String {
        summaries.first.map { String($0.prefix(MessageBookmarkNavigation.snippetLength)) } ?? ""
    }

    static func snippet(of entry: TranscriptEntry) -> String {
        guard case .assistantMessage(let text) = entry.content else { return MessageBookmarkNavigation.snippet(of: entry) ?? "" }
        let head = String(text.prefix(snippetSourceLength))
        if isMarkdownInert(head) {
            let collapsed = MessageBookmarkNavigation.collapsedHead(of: [head])
            if !collapsed.isCut { return collapsed.snippet }
        }
        return MessageBookmarkNavigation.snippet(
            of: TranscriptEntry(
                id: entry.id, content: .assistantMessage(head),
                timestamp: nil, startsTurn: false)) ?? ""
    }

    /// Markdown reads `text` as plain paragraphs whose text differs from it only in whitespace: no character it acts on,
    /// no control character but LF, no line starting like a block (a marker, a digit, four spaces, or the ':' of a table's
    /// delimiter row, which needs no pipes), no space it strips next to a byte past ASCII (the two can be one Character),
    /// and no U+FEFF, which it drops.
    static func isMarkdownInert(_ text: String) -> Bool {
        text.utf8.withContiguousStorageIfAvailable { bytes in
            var atLineStart = true
            var leadingSpaces = 0
            var trailingSpaces = 0
            var lastByteOtherThanSpaceOrNewline: UInt8 = 0
            for byte in bytes {
                switch byte {
                case UInt8(ascii: "\n"):
                    if trailingSpaces > 0, lastByteOtherThanSpaceOrNewline >= 0x80 { return false }
                    atLineStart = true
                    leadingSpaces = 0
                    trailingSpaces = 0
                    continue
                case UInt8(ascii: " "):
                    if !atLineStart { trailingSpaces += 1 } else if leadingSpaces == 3 { return false } else { leadingSpaces += 1 }
                    continue
                case 0..<0x20, 0x7F, UInt8(ascii: "!"), UInt8(ascii: "#"), UInt8(ascii: "&"), UInt8(ascii: "*"), UInt8(ascii: "<"),
                    UInt8(ascii: ">"), UInt8(ascii: "["), UInt8(ascii: "\\"), UInt8(ascii: "]"), UInt8(ascii: "_"),
                    UInt8(ascii: "`"), UInt8(ascii: "|"), UInt8(ascii: "~"):
                    return false
                case UInt8(ascii: "+"), UInt8(ascii: "-"), UInt8(ascii: "="), UInt8(ascii: ":"), UInt8(ascii: "0")...UInt8(ascii: "9"):
                    if atLineStart { return false }
                case 0x80...:
                    if atLineStart && leadingSpaces > 0 || lastByteOtherThanSpaceOrNewline == 0xEF && byte == 0xBB { return false }
                default: break
                }
                atLineStart = false
                trailingSpaces = 0
                lastByteOtherThanSpaceOrNewline = byte
            }
            return trailingSpaces == 0 || lastByteOtherThanSpaceOrNewline < 0x80
        } ?? false
    }

    static func lineWidthsCountingUTF8LeadBytes(of text: String, maximumLines: Int) -> [UInt8] {
        var widths: [UInt8] = []
        var column = 0
        var hasText = false
        var endsWrapped = false
        for byte in text.utf8.prefix(maximumLines * columns * maximumUTF8BytesPerScalar) {
            let isUTF8LeadByte = byte & 0xC0 != 0x80
            if byte == UInt8(ascii: "\n") {
                if hasText, !endsWrapped, !(column == 0 && widths.last == 0) { widths.append(UInt8(column)) }
                column = 0
                endsWrapped = false
            } else if isUTF8LeadByte, byte != UInt8(ascii: "\r") {
                hasText = true
                endsWrapped = false
                column += 1
                if column == columns {
                    widths.append(UInt8(columns))
                    column = 0
                    endsWrapped = true
                }
            }
            if widths.count >= maximumLines { break }
        }
        if column > 0, widths.count < maximumLines { widths.append(UInt8(column)) }
        while widths.last == 0 { widths.removeLast() }
        return widths.isEmpty ? [1] : widths
    }

    static func makesBlock(_ entry: TranscriptEntry) -> Bool { Block.Kind(entry.content) != nil }

    static func resumePoint(in blocks: [Block]) -> (keptCount: Int, record: Int)? {
        guard var cut = blocks.indices.last else { return nil }
        var record = blocks[cut].record
        while cut > 0, blocks[cut - 1].lastRecord >= record {
            cut -= 1
            record = blocks[cut].record
        }
        return (cut, record)
    }

    static func startsLike(_ block: Block, _ entry: TranscriptEntry) -> Bool {
        guard TranscriptPageIdentity.record(for: entry.id) == block.record, Block.Kind(entry.content) == block.kind else { return false }
        return !block.isMessage || MessageBookmarkNavigation.snippet(snippet(of: entry), stillStartsLike: block.snippet)
    }
}
