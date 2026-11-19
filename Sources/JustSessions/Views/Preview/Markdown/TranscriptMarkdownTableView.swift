import SwiftUI

struct TranscriptMarkdownTableView: View {
    let table: TranscriptMarkdownTable
    var segmentIndex = 0
    var indentation: CGFloat = 0
    @Environment(\.transcriptReadingFontSize) private var fontSize
    @Environment(\.transcriptColumnWidth) private var columnWidth

    var body: some View {
        ScrollView(.horizontal) {
            TranscriptMarkdownTableLayout(
                rowCellCounts: table.rows.map(\.cells.count),
                availableWidth: max(TranscriptMarkdownTableLayout.minimumColumnWidth, columnWidth - indentation),
                minimumWidths: longestWordWidths
            ) {
                ForEach(Array(table.rows.enumerated()), id: \.element.id) { rowIndex, row in
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { cellIndex, cell in
                        TranscriptTextBlock(
                            source: cell,
                            segmentIndex: segmentIndex + table.rows.prefix(rowIndex).reduce(0) { $0 + $1.cells.count } + cellIndex,
                            style: TranscriptTextStyle(fontSize: fontSize, isSemibold: row.isHeader),
                            copyRole: .tableCell(row: rowIndex)
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(row.isHeader ? ThemePalette.trackFill : ThemePalette.hoverFill)
                    }
                }
            }
        }
        .overlay(RoundedRectangle(.card).stroke(ThemePalette.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(.card))
    }

    private var longestWordWidths: [CGFloat] {
        var widths: [CGFloat] = []
        for row in table.rows {
            let font = TranscriptTextStyle(fontSize: fontSize, isSemibold: row.isHeader).font
            for (column, cell) in row.cells.enumerated() {
                let word = String(cell.characters).split(whereSeparator: \.isWhitespace).max { $0.count < $1.count }
                let width = word.map { (String($0) as NSString).size(withAttributes: [.font: font]).width + 24 } ?? 0
                if column < widths.count { widths[column] = max(widths[column], width) } else { widths.append(width) }
            }
        }
        return widths
    }
}

extension EnvironmentValues {
    @Entry var transcriptColumnWidth: CGFloat = TranscriptReadingWidth.readableColumnWidth
}
