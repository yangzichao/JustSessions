import Foundation

/// Native distances also change while scrolling inside a single tall message.
struct TranscriptPagingViewport {
    enum Direction { case earlier, later }

    let distanceToEarlier: CGFloat
    let distanceToLater: CGFloat
    let height: CGFloat
    private let visible: CGRect
    private let documentMaxY: CGFloat

    init(document: CGRect, visible: CGRect) {
        distanceToEarlier = max(0, visible.minY - document.minY)
        distanceToLater = max(0, document.maxY - visible.maxY)
        height = visible.height
        self.visible = visible
        documentMaxY = document.maxY
    }

    /// How near an edge of the loaded pages the viewport comes before the next page loads there.
    var prefetchDistance: CGFloat { min(600, max(160, height)) }

    func prefetchDirection(hasEarlier: Bool, hasLater: Bool, retainedPageCount: Int) -> Direction? {
        guard height > 0 else { return nil }
        let nearEarlier = distanceToEarlier <= prefetchDistance
        let nearLater = distanceToLater <= prefetchDistance
        // A very short window can expose both edges at once. Fill it only up to the memory budget,
        // rather than repeatedly evicting a page and immediately loading it from the opposite edge.
        guard !(nearEarlier && nearLater && retainedPageCount >= TranscriptPagingModel.maximumPageCount) else { return nil }
        if nearEarlier && hasEarlier && (!nearLater || !hasLater || distanceToEarlier < distanceToLater) { return .earlier }
        if nearLater && hasLater { return .later }
        return nil
    }

    /// How many pages to keep once a page loads in `direction`: those loaded now, which start at `pageStarts` in
    /// document order, and the new one. Pages leave from the opposite end as usual, down to
    /// `TranscriptPagingModel.maximumPageCount`, but only those clear of the viewport by a prefetch distance and a
    /// screen. A page that left any nearer would load straight back and push out the page just loaded; short pages,
    /// such as a few screenshots each, traded places that way while the reader bounced between them.
    ///
    /// A start is nil for a page whose rows are not laid out, such as one with no visible entries; it starts where the
    /// next page does.
    func retainedPageCount(afterLoading direction: Direction, pageStarts: [CGFloat?]) -> Int {
        var starts: [CGFloat] = []
        var nextStart = documentMaxY
        for start in pageStarts.reversed() {
            nextStart = start ?? nextStart
            starts.insert(nextStart, at: 0)
        }
        let ends = Array(starts.dropFirst()) + [documentMaxY]
        let clearance = prefetchDistance + height
        let clearPageCount = switch direction {
        case .earlier: starts.reversed().prefix { $0 >= visible.maxY + clearance }.count
        case .later: ends.prefix { $0 <= visible.minY - clearance }.count
        }
        let loadedCount = starts.count + 1
        let usualLeavingCount = max(0, loadedCount - TranscriptPagingModel.maximumPageCount)
        return min(TranscriptPagingModel.maximumRetainedPageCount, loadedCount - min(usualLeavingCount, clearPageCount))
    }
}
