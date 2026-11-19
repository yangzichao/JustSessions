import Testing

@testable import JustSessions

struct TranscriptTextSelectionCopyTests {
    private static func piece(
        _ entryIndex: Int, _ segmentIndex: Int, _ role: TranscriptTextCopyRole, _ text: String, startsAtBlockStart: Bool = true
    ) -> TranscriptTextSelectionCopy.Piece {
        TranscriptTextSelectionCopy.Piece(
            key: TranscriptTextSelectionKey(entryIndex: entryIndex, segmentIndex: segmentIndex), role: role, text: text,
            startsAtBlockStart: startsAtBlockStart
        )
    }

    /// Paragraphs and messages are a blank line apart; list items and tool calls one per line; table cells a tab apart
    /// in a row and a line apart between rows. A code block's final line break does not add to the blank line after it.
    @Test func joinsBlocksAsTheyRead() {
        let text = TranscriptTextSelectionCopy.text(of: [
            Self.piece(0, 0, .paragraph, "tail of the question", startsAtBlockStart: false),
            Self.piece(1, 0, .paragraph, "Intro"),
            Self.piece(1, 1, .listItem(marker: "•"), "First"),
            Self.piece(1, 2, .listItem(marker: "  1."), "Nested"),
            Self.piece(1, 3, .tableCell(row: 0), "Name"),
            Self.piece(1, 4, .tableCell(row: 0), "Value"),
            Self.piece(1, 5, .tableCell(row: 1), "rows"),
            Self.piece(1, 6, .tableCell(row: 1), "12"),
            Self.piece(1, 7, .paragraph, "let x = 1\n"),
            Self.piece(2, 0, .line, "Read A.swift"),
            Self.piece(2, 1, .line, "Bash swift build"),
        ])

        #expect(
            text == """
                tail of the question

                Intro

                • First
                  1. Nested

                Name\tValue
                rows\t12

                let x = 1

                Read A.swift
                Bash swift build
                """)
    }

    /// A list item selected from partway through has no marker, and blocks with nothing selected add no separator.
    @Test func skipsMarkersOfPartialItemsAndEmptyPieces() {
        let text = TranscriptTextSelectionCopy.text(of: [
            Self.piece(0, 0, .paragraph, ""),
            Self.piece(1, 0, .listItem(marker: "•"), "end of item", startsAtBlockStart: false),
            Self.piece(1, 1, .listItem(marker: "•"), "next"),
            Self.piece(1, 2, .paragraph, ""),
        ])

        #expect(text == "end of item\n• next")
    }
}
