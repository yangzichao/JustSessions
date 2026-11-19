import Foundation

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

    var prefetchDistance: CGFloat { min(600, max(160, height)) }

    func prefetchDirection(hasEarlier: Bool, hasLater: Bool, retainedPageCount: Int) -> Direction? {
        guard height > 0 else { return nil }
        let nearEarlier = distanceToEarlier <= prefetchDistance
        let nearLater = distanceToLater <= prefetchDistance
        guard !(nearEarlier && nearLater && retainedPageCount >= TranscriptPagingModel.maximumPageCount) else { return nil }
        if nearEarlier && hasEarlier && (!nearLater || !hasLater || distanceToEarlier < distanceToLater) { return .earlier }
        if nearLater && hasLater { return .later }
        return nil
    }

    func retainedPageCount(afterLoading direction: Direction, pageStarts: [CGFloat?]) -> Int {
        var starts: [CGFloat] = []
        var nextStart = documentMaxY
        for start in pageStarts.reversed() {
            nextStart = start ?? nextStart
            starts.insert(nextStart, at: 0)
        }
        let ends = Array(starts.dropFirst()) + [documentMaxY]
        let clearance = prefetchDistance + height
        let clearPageCount =
            switch direction {
            case .earlier: starts.reversed().prefix { $0 >= visible.maxY + clearance }.count
            case .later: ends.prefix { $0 <= visible.minY - clearance }.count
            }
        let loadedCount = starts.count + 1
        let usualLeavingCount = max(0, loadedCount - TranscriptPagingModel.maximumPageCount)
        return min(TranscriptPagingModel.maximumRetainedPageCount, loadedCount - min(usualLeavingCount, clearPageCount))
    }
}
