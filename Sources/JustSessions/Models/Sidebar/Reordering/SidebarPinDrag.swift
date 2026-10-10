import CoreGraphics

/// A drag in the sidebar of a project among its host's projects, or of a session among its project's sessions. It
/// lands only among the pinned ones, since only they keep the order you put them in; the rest are listed by activity.
/// Letting go of a pinned one moves it, and of one that is not pinned, pins it there. The rows stay where they are
/// while a line shows where the dragged one would land, worked out on where they were as the drag began, so nothing
/// moves under the pointer mid-drag.
struct SidebarPinDrag: Equatable {
    enum Scope: Hashable {
        case projects(on: SessionHost)
        case sessions(inProject: String)
    }

    struct Row: Equatable {
        /// The row's id in the sidebar, which its frame is reported by.
        let rowID: String
        /// What `PinnedItems` keys it by; nil for a row that can't be pinned, such as a new session's tab.
        let pinID: String?
        let isPinned: Bool
    }

    let scope: Scope
    let draggedRowID: String
    /// Every row in the scope, top to bottom, the pinned ones first.
    let rows: [Row]
    /// Where the scope's rows in sight were as the drag began, in the list's coordinate space, by row id.
    let rowFrames: [String: CGRect]
    /// The bottom of the scope's lowest row in sight as the drag began, a session or a subagent's under a project.
    let scopeBottom: CGFloat?
    /// Where the pointer was as the drag began, from the top of the list.
    let startPointerY: CGFloat
    /// Where the pointer is now, from the top of the list.
    var pointerY: CGFloat

    private let draggedIndex: Int
    private let pinnedRowCount: Int

    /// Nil unless the dragged row is in the scope and can be pinned.
    init?(
        scope: Scope,
        dragging draggedRowID: String,
        rows: [Row],
        rowFrames: [String: CGRect],
        scopeBottom: CGFloat? = nil,
        pointerY: CGFloat
    ) {
        guard let draggedIndex = rows.firstIndex(where: { $0.rowID == draggedRowID }), rows[draggedIndex].pinID != nil else {
            return nil
        }
        self.scope = scope
        self.draggedRowID = draggedRowID
        self.rows = rows
        let rowIDs = Set(rows.map(\.rowID))
        self.rowFrames = rowFrames.filter { rowIDs.contains($0.key) }
        self.scopeBottom = scopeBottom
        startPointerY = pointerY
        self.pointerY = pointerY
        self.draggedIndex = draggedIndex
        pinnedRowCount = rows.prefix { $0.isPinned }.count
    }

    var draggedPinID: String? { rows[draggedIndex].pinID }

    /// How far the pointer has moved since the drag began, downward positive.
    var translation: CGFloat { pointerY - startPointerY }

    /// The gap between rows the dragged one would land in, 0 above the first row and `rows.count` below the last.
    /// Nil while letting go would change nothing: with the pointer still on the dragged row, past the pinned rows, or
    /// beside a pinned row's own place.
    var landingGap: Int? {
        guard let gap = pointedGap, gap <= pinnedRowCount else { return nil }
        if let draggedFrame = rowFrames[draggedRowID], draggedFrame.minY <= pointerY, pointerY < draggedFrame.maxY {
            return nil
        }
        if rows[draggedIndex].isPinned && (gap == draggedIndex || gap == draggedIndex + 1) { return nil }
        return gap
    }

    /// Where letting go puts the dragged row among the pinned ones, beside a pinned neighbor in sight.
    var placement: PinnedPlacement? {
        guard let gap = landingGap else { return nil }
        let isNeighbor = { (row: Row) in row.isPinned && row.rowID != draggedRowID }
        if let nextID = rows[gap...].first(where: isNeighbor)?.pinID { return .before(nextID) }
        if let previousID = rows[..<gap].last(where: isNeighbor)?.pinID { return .after(previousID) }
        return .last
    }

    /// The edge the landing line lies along, in the list's coordinate space: the top of the row below the landing gap,
    /// or, past the last row, which only happens when every row is pinned, the scope's bottom. Nil while nothing would
    /// land, or while that row is out of sight.
    var landingEdgeY: CGFloat? {
        guard let gap = landingGap else { return nil }
        guard gap < rows.count else { return scopeBottom }
        return rowFrames[rows[gap].rowID]?.minY
    }

    /// The gap below the last row whose middle the pointer has passed. Rows out of sight have no frame; they are
    /// above or below the ones in sight, so the gaps among them are counted all the same.
    private var pointedGap: Int? {
        let middlesInSight = rows.indices.compactMap { index in rowFrames[rows[index].rowID].map { (index, $0.midY) } }
        guard let firstInSight = middlesInSight.first else { return nil }
        let lastPassed = middlesInSight.last { $0.1 <= pointerY }
        return lastPassed.map { $0.0 + 1 } ?? firstInSight.0
    }
}
