import CoreGraphics

/// Where a window's terminals show, as a tab dragged over them finds where it would show, as a session dragged into
/// Claude Code's window or a tab dragged to the side of Chrome's: with no split shown, the third along any edge under
/// the pointer is the side the tab takes beside the shown tab, in a split that starts even, side by side along the left
/// and right edges and stacked along the top and bottom ones, and the middle shows the tab on its own, full size; with
/// a split shown, the pane under the pointer is the one the tab takes the place of, the resize area between the panes
/// parting them.
struct TerminalSplitDropArea: Equatable {
    /// With no split shown, the share of the width or height along each edge that splits; the rest, in the middle, does
    /// not.
    static let splitEdgeShare: CGFloat = 1.0 / 3

    /// The split shown in the area, as its panes are laid out.
    struct ShownSplit: Equatable {
        /// The first pane's share of the panes' length.
        var fraction: CGFloat
        var orientation: TerminalSplit.Orientation
    }

    /// In the window, from its top-leading corner.
    var frameInWindow: CGRect
    /// Nil while no split shows.
    var shownSplit: ShownSplit?

    /// Where a tab let go at `pointer`, in screen coordinates, shows, over the area's window, whose frame on screen is
    /// `windowFrame`; nil outside the area. `ignoringShownSplit` finds the edge, as with no split shown, for a split's
    /// own pane dragged to where its tab should sit in it.
    func place(atScreenPoint pointer: CGPoint, windowFrame: CGRect, ignoringShownSplit: Bool = false) -> TerminalDropPlace? {
        let point = CGPoint(x: pointer.x - windowFrame.minX, y: windowFrame.maxY - pointer.y)
        return ignoringShownSplit ? edgePlace(at: point) : place(at: point)
    }

    /// Where a tab let go at `point`, in the window from its top-leading corner, shows; nil outside the area.
    func place(at point: CGPoint) -> TerminalDropPlace? {
        guard let shownSplit else { return edgePlace(at: point) }
        guard frameInWindow.contains(point) else { return nil }
        let boundary = paneFrames.resizeArea
        let isBeforeBoundary = shownSplit.orientation == .sideBySide
            ? point.x < frameInWindow.minX + boundary.midX
            : point.y < frameInWindow.minY + boundary.midY
        return .split(isBeforeBoundary ? .left : .right, shownSplit.orientation)
    }

    /// The edge whose third the point is in, the nearest for its share of the area where two thirds meet in a corner,
    /// or the whole area in the middle, as with no split shown; nil outside the area.
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

    /// Where the tab dropped at `place` shows, in the area's coordinates: that side's pane of the shown split, or the
    /// half of a new, even split laid out the place's way; or the whole area inside the insets a split's panes have.
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
