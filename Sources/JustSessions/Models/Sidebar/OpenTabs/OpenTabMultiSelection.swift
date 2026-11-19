import Foundation

/// Tabs selected in the sidebar's Open tabs list to close together, picked as sessions are in Projects: Command toggles a
/// row and Shift selects the range between the anchor and the clicked row. A plain click shows its tab instead and
/// clears the selection, so the selection only ever holds rows picked with Command or Shift.
struct OpenTabMultiSelection: Equatable {
    private(set) var selectedTabIDs: Set<UUID> = []
    /// Start of the next Shift-click range: the last row clicked with Command, or the shown tab's row.
    private(set) var anchorTabID: UUID?

    var isEmpty: Bool { selectedTabIDs.isEmpty }
    var hasMultipleSelected: Bool { selectedTabIDs.count > 1 }

    func contains(_ tabID: UUID) -> Bool {
        selectedTabIDs.contains(tabID)
    }

    mutating func toggle(_ tabID: UUID) {
        if selectedTabIDs.remove(tabID) == nil {
            selectedTabIDs.insert(tabID)
        }
        anchorTabID = tabID
    }

    /// The shown tab's row is highlighted while nothing is selected, so it counts as selected: a ⌘- or Shift-click that
    /// follows adds to it.
    mutating func selectShownTabWhileNothingIsSelected(_ shownTabID: UUID?) {
        guard selectedTabIDs.isEmpty, let shownTabID else { return }
        selectedTabIDs = [shownTabID]
        anchorTabID = shownTabID
    }

    /// `orderedTabIDs` holds the rows in sight, so a range skips the tabs of collapsed groups.
    mutating func selectRange(to tabID: UUID, in orderedTabIDs: [UUID]) {
        guard let anchorTabID,
            let anchorIndex = orderedTabIDs.firstIndex(of: anchorTabID),
            let targetIndex = orderedTabIDs.firstIndex(of: tabID)
        else {
            selectedTabIDs = [tabID]
            anchorTabID = tabID
            return
        }
        let rangeBounds = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selectedTabIDs = Set(orderedTabIDs[rangeBounds])
    }

    mutating func clear() {
        selectedTabIDs = []
        anchorTabID = nil
    }

    /// Closed tabs, and tabs a search hides, leave the selection, so closing it only closes rows the list shows.
    mutating func keepOnly(_ listedTabIDs: Set<UUID>) {
        selectedTabIDs.formIntersection(listedTabIDs)
        if let anchorTabID, !listedTabIDs.contains(anchorTabID) {
            self.anchorTabID = nil
        }
    }
}
