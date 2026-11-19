import SwiftUI

struct TranscriptMarkdownTableLayout: Layout {
    static let minimumColumnWidth: CGFloat = 120
    static let maximumWordWidth: CGFloat = 240

    let rowCellCounts: [Int]
    let availableWidth: CGFloat
    var minimumWidths: [CGFloat] = []

    struct Cache {
        var columnWidths: [CGFloat] = []
        var rowHeights: [CGFloat] = []
        var isMeasured = false
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = Cache() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        measure(subviews, into: &cache)
        return CGSize(width: cache.columnWidths.reduce(0, +), height: cache.rowHeights.reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        measure(subviews, into: &cache)
        var index = 0
        var y = bounds.minY
        for (row, count) in rowCellCounts.enumerated() {
            var x = bounds.minX
            for column in 0..<count where index < subviews.count {
                let size = CGSize(width: cache.columnWidths[column], height: cache.rowHeights[row])
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width
                index += 1
            }
            y += cache.rowHeights[row]
        }
    }

    private func measure(_ subviews: Subviews, into cache: inout Cache) {
        guard !cache.isMeasured else { return }
        let columnCount = rowCellCounts.max() ?? 0
        var idealWidths = [CGFloat](repeating: 0, count: columnCount)
        var index = 0
        for count in rowCellCounts {
            for column in 0..<count where index < subviews.count {
                idealWidths[column] = max(idealWidths[column], subviews[index].sizeThatFits(.unspecified).width)
                index += 1
            }
        }
        let minimums = idealWidths.indices.map { column in
            max(Self.minimumColumnWidth, min(Self.maximumWordWidth, column < minimumWidths.count ? minimumWidths[column] : 0))
        }
        let columnWidths = Self.columnWidths(idealWidths: idealWidths, minimumWidths: minimums, availableWidth: availableWidth)
        var rowHeights: [CGFloat] = []
        index = 0
        for count in rowCellCounts {
            var height: CGFloat = 0
            for column in 0..<count where index < subviews.count {
                height = max(height, subviews[index].sizeThatFits(ProposedViewSize(width: columnWidths[column], height: nil)).height)
                index += 1
            }
            rowHeights.append(height)
        }
        cache = Cache(columnWidths: columnWidths, rowHeights: rowHeights, isMeasured: true)
    }

    static func columnWidths(idealWidths: [CGFloat], minimumWidths: [CGFloat], availableWidth: CGFloat) -> [CGFloat] {
        let ideal = idealWidths.map { $0.rounded(.up) }
        guard ideal.reduce(0, +) > availableWidth else { return ideal }
        let lowest = ideal.indices.map { min(ideal[$0], ($0 < minimumWidths.count ? minimumWidths[$0] : 0).rounded(.up)) }
        guard lowest.reduce(0, +) < availableWidth else { return lowest }
        func widths(cappedAt cap: CGFloat) -> [CGFloat] { ideal.indices.map { max(lowest[$0], min(ideal[$0], cap)) } }
        var low: CGFloat = 0
        var high = ideal.max() ?? 0
        for _ in 0..<48 {
            let middle = (low + high) / 2
            if widths(cappedAt: middle).reduce(0, +) > availableWidth { high = middle } else { low = middle }
        }
        let roundedUp = widths(cappedAt: low.rounded(.up))
        return roundedUp.reduce(0, +) <= availableWidth ? roundedUp : widths(cappedAt: low.rounded(.down))
    }
}
