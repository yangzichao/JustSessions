import Foundation

enum TranscriptTextCopyRole: Hashable {
    case paragraph
    case listItem(marker: String)
    case tableCell(row: Int)
    case line
}

enum TranscriptTextSelectionCopy {
    struct Piece: Equatable {
        let key: TranscriptTextSelectionKey
        let role: TranscriptTextCopyRole
        let text: String
        let startsAtBlockStart: Bool
    }

    static func text(of pieces: [Piece]) -> String {
        var text = ""
        var previousPiece: Piece?
        for piece in pieces where !piece.text.isEmpty {
            if let previousPiece {
                while text.hasSuffix("\n") { text.removeLast() }
                text += separator(between: previousPiece, and: piece)
            }
            if piece.startsAtBlockStart, case .listItem(let marker) = piece.role { text += marker + " " }
            text += piece.text
            previousPiece = piece
        }
        return text
    }

    private static func separator(between previousPiece: Piece, and piece: Piece) -> String {
        guard previousPiece.key.entryIndex == piece.key.entryIndex else { return "\n\n" }
        switch (previousPiece.role, piece.role) {
        case (.tableCell(let previousRow), .tableCell(let row)): return previousRow == row ? "\t" : "\n"
        case (.listItem, .listItem), (.line, .line): return "\n"
        default: return "\n\n"
        }
    }
}
