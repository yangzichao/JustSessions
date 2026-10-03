import Foundation

struct TranscriptMarkdownBlock: Identifiable, Sendable, Equatable {
    enum Content: Sendable, Equatable {
        case text(AttributedString, headingLevel: Int?)
        case code(String, language: String?)
        case table(TranscriptMarkdownTable)
        case divider
    }

    let id: Int
    var content: Content
    let listDepth: Int
    let listMarker: String?
    let quoteDepth: Int
}

struct TranscriptMarkdownTable: Sendable, Equatable {
    struct Row: Identifiable, Sendable, Equatable {
        let id: Int
        let isHeader: Bool
        var cells: [AttributedString]
    }

    var rows: [Row]
}
