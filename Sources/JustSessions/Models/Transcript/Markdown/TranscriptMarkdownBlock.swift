import Foundation

struct TranscriptMarkdownBlock: Identifiable, Equatable {
    enum Content: Equatable {
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

struct TranscriptMarkdownTable: Equatable {
    struct Row: Identifiable, Equatable {
        let id: Int
        let isHeader: Bool
        var cells: [AttributedString]
    }

    var rows: [Row]
}
