import Foundation

/// Native distances also change while scrolling inside a single tall message.
struct TranscriptPagingViewport {
    enum Direction { case earlier, later }

    let distanceToEarlier: CGFloat
    let distanceToLater: CGFloat
    let height: CGFloat

    init(document: CGRect, visible: CGRect) {
        distanceToEarlier = max(0, visible.minY - document.minY)
        distanceToLater = max(0, document.maxY - visible.maxY)
        height = visible.height
    }

    func prefetchDirection(hasEarlier: Bool, hasLater: Bool, retainedPageCount: Int) -> Direction? {
        guard height > 0 else { return nil }
        let prefetchDistance = min(600, max(160, height))
        let nearEarlier = distanceToEarlier <= prefetchDistance
        let nearLater = distanceToLater <= prefetchDistance
        // A very short window can expose both edges at once. Fill it only up to the memory budget,
        // rather than repeatedly evicting a page and immediately loading it from the opposite edge.
        guard !(nearEarlier && nearLater && retainedPageCount >= TranscriptPagingModel.maximumPageCount) else { return nil }
        if nearEarlier && hasEarlier && (!nearLater || !hasLater || distanceToEarlier < distanceToLater) { return .earlier }
        if nearLater && hasLater { return .later }
        return nil
    }
}
