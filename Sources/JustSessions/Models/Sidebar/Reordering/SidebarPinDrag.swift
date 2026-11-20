import CoreGraphics

struct SidebarPinDrag: Equatable {
    enum Scope: Hashable {
        case projects(on: SessionHost)
        case sessions(inProject: String)
    }

    struct Row: Equatable {
        let rowID: SidebarRowID
        let pinID: String?
        let isPinned: Bool
    }

    let scope: Scope
    let draggedRowID: SidebarRowID
    let rows: [Row]
    let rowFrames: [SidebarRowID: CGRect]
    let scopeBottom: CGFloat?
    let startPointerY: CGFloat
    var pointerY: CGFloat
    private(set) var isPointerBesideList = false

    private let draggedIndex: Int
    private let pinnedRowCount: Int

    init?(
        scope: Scope,
        dragging draggedRowID: SidebarRowID,
        rows: [Row],
        rowFrames: [SidebarRowID: CGRect],
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

    mutating func movePointer(to pointer: CGPoint) {
        pointerY = pointer.y
        isPointerBesideList = rowFrames[draggedRowID].map { pointer.x < $0.minX || pointer.x > $0.maxX } ?? false
    }

    var translation: CGFloat { pointerY - startPointerY }

    var landingGap: Int? {
        guard !isPointerBesideList, let gap = pointedGap, gap <= pinnedRowCount else { return nil }
        if let draggedFrame = rowFrames[draggedRowID], draggedFrame.minY <= pointerY, pointerY < draggedFrame.maxY {
            return nil
        }
        if rows[draggedIndex].isPinned && (gap == draggedIndex || gap == draggedIndex + 1) { return nil }
        return gap
    }

    var placement: PinnedPlacement? {
        guard let gap = landingGap else { return nil }
        let isNeighbor = { (row: Row) in row.isPinned && row.rowID != draggedRowID }
        if let nextID = rows[gap...].first(where: isNeighbor)?.pinID { return .before(nextID) }
        if let previousID = rows[..<gap].last(where: isNeighbor)?.pinID { return .after(previousID) }
        return .last
    }

    var landingEdgeY: CGFloat? {
        guard let gap = landingGap else { return nil }
        guard gap < rows.count else { return scopeBottom }
        return rowFrames[rows[gap].rowID]?.minY
    }

    private var pointedGap: Int? {
        let middlesInSight = rows.indices.compactMap { index in rowFrames[rows[index].rowID].map { (index, $0.midY) } }
        guard let firstInSight = middlesInSight.first else { return nil }
        let lastPassed = middlesInSight.last { $0.1 <= pointerY }
        return lastPassed.map { $0.0 + 1 } ?? firstInSight.0
    }
}
