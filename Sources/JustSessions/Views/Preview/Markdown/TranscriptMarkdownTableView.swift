import SwiftUI

struct TranscriptMarkdownTableView: View {
    let table: TranscriptMarkdownTable
    var segmentIndex = 0
    @Environment(\.transcriptReadingFontSize) private var fontSize

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Array(table.rows.enumerated()), id: \.element.id) { rowIndex, row in
                    GridRow {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { cellIndex, cell in
                            TranscriptSearchableText(
                                source: TranscriptReadingTypography.inlineText(cell, fontSize: fontSize),
                                segmentIndex: segmentIndex + table.rows.prefix(rowIndex).reduce(0) { $0 + $1.cells.count } + cellIndex,
                                fontSize: fontSize, isSemibold: row.isHeader
                            )
                                .fontWeight(row.isHeader ? .semibold : .regular)
                                .textSelection(.enabled)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .frame(maxWidth: 260, alignment: .leading)
                                .background(row.isHeader ? ThemePalette.trackFill : ThemePalette.hoverFill)
                        }
                    }
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThemePalette.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
