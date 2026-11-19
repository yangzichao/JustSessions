import Foundation

struct OpenTabMultiSelection: Equatable {
    private(set) var selectedTabIDs: Set<UUID> = []
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

    mutating func selectShownTabWhileNothingIsSelected(_ shownTabID: UUID?) {
        guard selectedTabIDs.isEmpty, let shownTabID else { return }
        selectedTabIDs = [shownTabID]
        anchorTabID = shownTabID
    }

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

    mutating func keepOnly(_ listedTabIDs: Set<UUID>) {
        selectedTabIDs.formIntersection(listedTabIDs)
        if let anchorTabID, !listedTabIDs.contains(anchorTabID) {
            self.anchorTabID = nil
        }
    }
}
