import Foundation

/// Search and rendering use the same segment order, including code and individual table cells.
enum TranscriptSearchSegments {
    static func texts(in entry: TranscriptEntry) -> [String] {
        entry.markdown?.searchSegments ?? texts(in: entry.content)
    }

    static func texts(in content: TranscriptEntry.Content) -> [String] {
        switch content {
        case .userMessage(let text), .note(let text): [text]
        case .toolCalls(let summaries): summaries
        case .assistantMessage(let text): TranscriptMarkdownParser.blocks(from: text).flatMap(texts(in:))
        case .userImage, .toolResultImage: []
        }
    }

    static func texts(in block: TranscriptMarkdownBlock) -> [String] {
        switch block.content {
        case .text(let text, _): [String(text.characters)]
        case .code(let text, _): [text]
        case .table(let table): table.rows.flatMap { $0.cells.map { String($0.characters) } }
        case .divider: []
        }
    }

    static func startingIndices(in blocks: [TranscriptMarkdownBlock]) -> [Int: Int] {
        var nextIndex = 0
        return Dictionary(uniqueKeysWithValues: blocks.map { block in
            defer {
                switch block.content {
                case .text, .code: nextIndex += 1
                case .table(let table): nextIndex += table.rows.reduce(0) { $0 + $1.cells.count }
                case .divider: break
                }
            }
            return (block.id, nextIndex)
        })
    }
}
