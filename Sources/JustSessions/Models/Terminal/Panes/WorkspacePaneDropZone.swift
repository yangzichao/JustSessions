import CoreGraphics

/// Where a dragged tab would land in a pane: docked to one of its edges, or moved into its middle.
enum WorkspacePaneDropZone: Equatable {
    case center
    case edge(WorkspacePaneEdge)

    /// The drag gesture and the pane area resolve drag locations in this shared coordinate space.
    static let coordinateSpaceName = "workspacePaneArea"

    /// How much of a pane's width or height belongs to each edge band. The middle is the move zone.
    private static let edgeBand = 0.3

    /// The zone under `point`, or nil outside `rect`.
    static func zone(at point: CGPoint, in rect: CGRect) -> WorkspacePaneDropZone? {
        guard rect.contains(point), rect.width > 0, rect.height > 0 else { return nil }
        let x = (point.x - rect.minX) / rect.width
        let y = (point.y - rect.minY) / rect.height
        let distances: [(edge: WorkspacePaneEdge, distance: CGFloat)] = [
            (.leading, x), (.trailing, 1 - x), (.top, y), (.bottom, 1 - y),
        ]
        let nearest = distances.min { $0.distance < $1.distance }!
        return nearest.distance < edgeBand ? .edge(nearest.edge) : .center
    }

    /// The pane under `point` and the zone within it; nil over dividers and outside every pane.
    static func target(
        at point: CGPoint,
        in resolution: WorkspacePaneGeometry.Resolution
    ) -> (content: WorkspacePaneContent, zone: WorkspacePaneDropZone)? {
        for (content, rect) in resolution.paneRects {
            if let zone = zone(at: point, in: rect) { return (content, zone) }
        }
        return nil
    }

    /// What the highlight covers while this zone is hovered: the half of the pane a docked tab would take,
    /// or the whole pane for a move.
    func highlightRect(in rect: CGRect) -> CGRect {
        switch self {
        case .center:
            return rect
        case .edge(.leading):
            return CGRect(x: rect.minX, y: rect.minY, width: (rect.width / 2).rounded(), height: rect.height)
        case .edge(.trailing):
            let width = (rect.width / 2).rounded()
            return CGRect(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height)
        case .edge(.top):
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: (rect.height / 2).rounded())
        case .edge(.bottom):
            let height = (rect.height / 2).rounded()
            return CGRect(x: rect.minX, y: rect.maxY - height, width: rect.width, height: height)
        }
    }
}
