import Foundation

/// Search and rendering use the same segment order, including code and individual table cells.
enum TranscriptSearchSegments {
    static func texts(in content: TranscriptEntry.Content) -> [String] {
        switch content {
        case .userMessage(let text), .note(let text): [text]
        case .toolCalls(let summaries): summaries
        case .assistantMessage(let text): TranscriptMarkdownParser.blocks(from: text).flatMap(texts(in:))
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
            defer { nextIndex += texts(in: block).count }
            return (block.id, nextIndex)
        })
    }
}
