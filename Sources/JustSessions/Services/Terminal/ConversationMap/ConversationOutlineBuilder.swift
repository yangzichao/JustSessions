import Foundation

/// Entries, page after page, into map blocks. Tool calls and their images merge into one run however pages fall, with
/// no 50-summary cap (unlike TranscriptPageAssembler.swift:9-15), so blocks never depend on page sizes.
struct ConversationOutlineBuilder {
    static let columns = 80
    static let maximumLinesPerMessage = 24
    static let maximumLinesPerToolRun = 4
    /// Enough of a reply's head for its 80-character snippet; the rest is never parsed as Markdown.
    static let snippetSourceLength = 400
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
            case .note: continue  // left out; doesn't break a run
            }
        }
    }

    private mutating func appendMessage(_ kind: Block.Kind, _ text: String, _ entry: TranscriptEntry, _ record: Int) {
        blocks.append(
            Block(
                entryID: entry.id, lastRecord: record, kind: kind, timestamp: entry.timestamp,
                snippet: Self.snippet(of: entry),
                lineWidths: Self.lineWidths(of: text, maximumLines: Self.maximumLinesPerMessage), toolCallCount: 0))
    }

    private mutating func appendToolCalls(_ summaries: [String], _ entry: TranscriptEntry, _ record: Int) {
        let widths = summaries.prefix(Self.maximumLinesPerToolRun).map { UInt8($0.prefix(Self.columns).count) }
        if let last = blocks.indices.last, blocks[last].kind == .toolRun {
            blocks[last].toolCallCount += summaries.count
            blocks[last].lastRecord = record
            blocks[last].lineWidths = Array((blocks[last].lineWidths + widths).prefix(Self.maximumLinesPerToolRun))
            if blocks[last].snippet.isEmpty, let first = summaries.first {
                blocks[last].snippet = String(first.prefix(MessageBookmarkNavigation.snippetLength))
            }
        } else {
            blocks.append(
                Block(
                    entryID: entry.id, lastRecord: record, kind: .toolRun, timestamp: entry.timestamp,
                    snippet: summaries.first.map { String($0.prefix(MessageBookmarkNavigation.snippetLength)) } ?? "",
                    lineWidths: widths.isEmpty ? [8] : widths, toolCallCount: summaries.count))
        }
    }

    /// The bookmark snippet's rule (MessageBookmarkNavigation.swift:17-27): a user message's own text, a reply's first
    /// `snippetSourceLength` characters, so a 12,000-character reply's Markdown is never parsed whole. The reader parses
    /// the whole reply, so the two differ when Markdown crosses character 400 or the head runs out of words; a bookmark's
    /// chip then falls back to its ID (ConversationOutline.blockIndex(for:)). A Markdown-inert
    /// head isn't parsed at all (PERF-90): its paragraphs hold the same words with less whitespace, so they give the same
    /// snippet unless the 320-character cut ended the head's words.
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
            var previous: UInt8 = 0  // the last byte but a space or LF
            for byte in bytes {
                switch byte {
                case UInt8(ascii: "\n"):
                    if trailingSpaces > 0, previous >= 0x80 { return false }
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
                    if atLineStart && leadingSpaces > 0 || previous == 0xEF && byte == 0xBB { return false }
                default: break
                }
                atLineStart = false
                trailingSpaces = 0
                previous = byte
            }
            return trailingSpaces == 0 || previous < 0x80
        } ?? false
    }

    /// Line lengths in map columns, counting UTF-8 lead bytes (not graphemes) over at most maximumLines × columns × 4 bytes.
    /// Wraps at `columns`; blank lines at the ends go; a run of blank lines inside is one 0.
    static func lineWidths(of text: String, maximumLines: Int) -> [UInt8] {
        var widths: [UInt8] = []
        var column = 0
        var hasText = false
        var endsWrapped = false
        for byte in text.utf8.prefix(maximumLines * columns * 4) {
            if byte == UInt8(ascii: "\n") {
                if hasText, !endsWrapped, !(column == 0 && widths.last == 0) { widths.append(UInt8(column)) }
                column = 0
                endsWrapped = false
            } else if byte & 0xC0 != 0x80, byte != UInt8(ascii: "\r") {
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

    /// Where an update reads again from: the last block's first record, moved back while the block before reaches into
    /// it (as a reply and its tool calls share a Claude record), so every kept block ends before it.
    static func resumePoint(in blocks: [Block]) -> (keptCount: Int, record: Int)? {
        guard var cut = blocks.indices.last else { return nil }
        var record = blocks[cut].record
        while cut > 0, blocks[cut - 1].lastRecord >= record {
            cut -= 1
            record = blocks[cut].record
        }
        return (cut, record)
    }

    /// The record read again still starts with the same block: its kind, and for a message the first 40 characters of
    /// its snippet, ignoring case, as `MessageBookmarkNavigation.matches` allows a reply to grow (:29-34).
    static func startsLike(_ block: Block, _ entry: TranscriptEntry) -> Bool {
        guard TranscriptPageIdentity.record(for: entry.id) == block.record, Block.Kind(entry.content) == block.kind else { return false }
        return !block.isMessage || snippet(of: entry).lowercased().hasPrefix(block.snippet.prefix(40).lowercased())
    }
}
