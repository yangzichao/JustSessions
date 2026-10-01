import Foundation

/// Foundation supplies the Markdown structure and inline attributes; the reader supplies its layout.
enum TranscriptMarkdownParser {
    static func blocks(from source: String) -> [TranscriptMarkdownBlock] {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        guard let attributedText = try? AttributedString(markdown: source, options: options) else {
            return [plainTextBlock(source)]
        }
        var blocks: [TranscriptMarkdownBlock] = []
        var seenListItems: Set<Int> = []
        for (intent, range) in attributedText.runs[\.presentationIntent] {
            guard let components = intent?.components, let leaf = components.first else { continue }
            let text = preservingLineBreaks(in: AttributedString(attributedText[range]))
            if let table = components.first(where: { if case .table = $0.kind { true } else { false } }) {
                appendTableCell(text, components: components, tableID: table.identity, to: &blocks)
                continue
            }
            let listItems = components.filter { if case .listItem = $0.kind { true } else { false } }
            var listMarker: String?
            if let item = listItems.first, seenListItems.insert(item.identity).inserted,
               case .listItem(let ordinal) = item.kind {
                // The closest list, rather than an outer ordered list, controls the marker.
                let nearestList = components.first { component in
                    switch component.kind { case .orderedList, .unorderedList: true; default: false }
                }
                let orderedMarker = nearestList.map { if case .orderedList = $0.kind { true } else { false } } ?? false
                listMarker = orderedMarker ? "\(ordinal)." : "•"
            }
            let content: TranscriptMarkdownBlock.Content = switch leaf.kind {
            case .header(let level): .text(text, headingLevel: level)
            case .codeBlock(let language): .code(String(text.characters), language: language)
            case .thematicBreak: .divider
            default: .text(text, headingLevel: nil)
            }
            blocks.append(TranscriptMarkdownBlock(
                id: leaf.identity, content: content, listDepth: listItems.count, listMarker: listMarker,
                quoteDepth: components.filter { if case .blockQuote = $0.kind { true } else { false } }.count
            ))
        }
        return blocks.isEmpty && !source.isEmpty ? [plainTextBlock(source)] : blocks
    }

    private static func preservingLineBreaks(in text: AttributedString) -> AttributedString {
        var result = AttributedString()
        for run in text.runs {
            if run.inlinePresentationIntent?.contains(.softBreak) == true {
                var attributes = run.attributes
                attributes.inlinePresentationIntent = run.inlinePresentationIntent?.subtracting(.softBreak)
                result.append(AttributedString("\n", attributes: attributes))
            } else {
                result.append(AttributedString(text[run.range]))
            }
        }
        result.presentationIntent = nil
        return result
    }

    private static func appendTableCell(
        _ text: AttributedString, components: [PresentationIntent.IntentType], tableID: Int,
        to blocks: inout [TranscriptMarkdownBlock]
    ) {
        guard let row = components.first(where: { component in
            switch component.kind { case .tableHeaderRow, .tableRow: true; default: false }
        }) else { return }
        let isHeader = if case .tableHeaderRow = row.kind { true } else { false }
        var table: TranscriptMarkdownTable
        if let last = blocks.last, last.id == tableID, case .table(let existingTable) = last.content {
            table = existingTable
            blocks.removeLast()
        } else {
            table = TranscriptMarkdownTable(rows: [])
        }
        if table.rows.last?.id == row.identity {
            table.rows[table.rows.count - 1].cells.append(text)
        } else {
            table.rows.append(.init(id: row.identity, isHeader: isHeader, cells: [text]))
        }
        blocks.append(TranscriptMarkdownBlock(id: tableID, content: .table(table), listDepth: 0, listMarker: nil, quoteDepth: 0))
    }

    private static func plainTextBlock(_ text: String) -> TranscriptMarkdownBlock {
        TranscriptMarkdownBlock(id: 0, content: .text(AttributedString(text), headingLevel: nil), listDepth: 0, listMarker: nil, quoteDepth: 0)
    }
}
