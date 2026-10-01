import SwiftUI

struct TranscriptMarkdownTableView: View {
    let table: TranscriptMarkdownTable
    @Environment(\.transcriptReadingFontSize) private var fontSize

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(table.rows) { row in
                    GridRow {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            Text(TranscriptReadingTypography.inlineText(cell, fontSize: fontSize))
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
