import SwiftUI

struct MessageBookmarkTagChip: View {
    let tag: String

    var body: some View {
        Text(verbatim: "#" + tag)
            .font(ThemeFont.caption)
            .foregroundStyle(ThemePalette.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ThemePalette.trackFill, in: RoundedRectangle(.small))
    }
}

struct MessageBookmarkTagList: View {
    let tags: [String]

    var body: some View {
        if !tags.isEmpty {
            MessageBookmarkFlowLayout(spacing: 4) {
                ForEach(tags, id: \.self) { MessageBookmarkTagChip(tag: $0) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: MessageBookmarkDetails.typedText(of: tags)))
        }
    }
}

struct MessageBookmarkFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthWithView = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty, widthWithView > width {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
