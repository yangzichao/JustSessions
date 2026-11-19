import Foundation

struct TerminalSplitChooser: Identifiable, Equatable {
    let id: UUID
    var tabID: UUID
    var side: TerminalSplit.Side
    var orientation: TerminalSplit.Orientation

    init(id: UUID = UUID(), tabID: UUID, side: TerminalSplit.Side = .right, orientation: TerminalSplit.Orientation = .sideBySide) {
        self.id = id
        self.tabID = tabID
        self.side = side
        self.orientation = orientation
    }

    var tabSide: TerminalSplit.Side {
        side == .left ? .right : .left
    }

    static func candidates(
        amongTabs tabIDs: [UUID],
        byLastSelected tabIDsByLastSelected: [UUID],
        isAvailable: (UUID) -> Bool
    ) -> [UUID] {
        let openTabIDs = Set(tabIDs)
        let selectedBefore = tabIDsByLastSelected.filter { openTabIDs.contains($0) }
        let neverSelected = tabIDs.filter { !selectedBefore.contains($0) }
        return (selectedBefore + neverSelected).filter(isAvailable)
    }
}
