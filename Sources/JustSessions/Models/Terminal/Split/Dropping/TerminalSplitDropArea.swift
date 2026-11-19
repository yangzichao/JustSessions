import CoreGraphics

struct TerminalSplitDropArea: Equatable {
    static let splitEdgeShare: CGFloat = 1.0 / 3

    struct ShownSplit: Equatable {
        var fraction: CGFloat
        var orientation: TerminalSplit.Orientation
    }

    var frameInWindow: CGRect
    var shownSplit: ShownSplit?

    func place(atScreenPoint pointer: CGPoint, windowFrame: CGRect, ignoringShownSplit: Bool = false) -> TerminalDropPlace? {
        let point = CGPoint(x: pointer.x - windowFrame.minX, y: windowFrame.maxY - pointer.y)
        return ignoringShownSplit ? edgePlace(at: point) : place(at: point)
    }

    func place(at point: CGPoint) -> TerminalDropPlace? {
        guard let shownSplit else { return edgePlace(at: point) }
        guard frameInWindow.contains(point) else { return nil }
        let boundary = paneFrames.resizeArea
        let isBeforeBoundary =
            shownSplit.orientation == .sideBySide
            ? point.x < frameInWindow.minX + boundary.midX
            : point.y < frameInWindow.minY + boundary.midY
        return .split(isBeforeBoundary ? .left : .right, shownSplit.orientation)
    }

    func edgePlace(at point: CGPoint) -> TerminalDropPlace? {
        guard frameInWindow.contains(point) else { return nil }
        let edgeWidth = frameInWindow.width * Self.splitEdgeShare
        let edgeHeight = frameInWindow.height * Self.splitEdgeShare
        let fromLeft = point.x - frameInWindow.minX
        let fromRight = frameInWindow.maxX - point.x
        let fromTop = point.y - frameInWindow.minY
        let fromBottom = frameInWindow.maxY - point.y
        let edges: [(place: TerminalDropPlace, isIn: Bool, share: CGFloat)] = [
            (.split(.left, .sideBySide), fromLeft < edgeWidth, fromLeft / frameInWindow.width),
            (.split(.right, .sideBySide), fromRight <= edgeWidth, fromRight / frameInWindow.width),
            (.split(.left, .stacked), fromTop < edgeHeight, fromTop / frameInWindow.height),
            (.split(.right, .stacked), fromBottom <= edgeHeight, fromBottom / frameInWindow.height),
        ]
        return edges.filter(\.isIn).min { $0.share < $1.share }?.place ?? .wholeArea
    }

    func frame(of place: TerminalDropPlace) -> CGRect {
        switch place {
        case .split(let side, let orientation):
            let fraction = shownSplit?.orientation == orientation ? shownSplit?.fraction : nil
            let frames = TerminalSplitLayout.frames(
                fraction: fraction ?? TerminalSplitLayout.evenFraction,
                size: frameInWindow.size,
                orientation: orientation
            )
            return side == .left ? frames.left : frames.right
        case .wholeArea:
            return CGRect(origin: .zero, size: frameInWindow.size)
                .insetBy(dx: TerminalSplitLayout.contentInset, dy: TerminalSplitLayout.contentInset)
        }
    }

    private var paneFrames: TerminalSplitLayout.Frames {
        TerminalSplitLayout.frames(
            fraction: shownSplit?.fraction ?? TerminalSplitLayout.evenFraction,
            size: frameInWindow.size,
            orientation: shownSplit?.orientation ?? .sideBySide
        )
    }
}
