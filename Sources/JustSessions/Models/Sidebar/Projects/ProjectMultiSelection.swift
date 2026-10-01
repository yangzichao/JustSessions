/// Project selection follows the displayed host and project order, independently of session rows.
struct ProjectMultiSelection: Equatable {
    private(set) var selectedProjectIDs: Set<String> = []
    private(set) var anchorProjectID: String?

    var hasSelection: Bool { !selectedProjectIDs.isEmpty }
    var hasMultipleSelected: Bool { selectedProjectIDs.count > 1 }

    func contains(_ projectID: String) -> Bool {
        selectedProjectIDs.contains(projectID)
    }

    mutating func selectOnly(_ projectID: String) {
        selectedProjectIDs = [projectID]
        anchorProjectID = projectID
    }

    mutating func toggle(_ projectID: String) {
        if selectedProjectIDs.remove(projectID) == nil {
            selectedProjectIDs.insert(projectID)
        }
        anchorProjectID = projectID
    }

    mutating func selectRange(to projectID: String, in orderedProjectIDs: [String]) {
        guard let anchorProjectID,
              let anchorIndex = orderedProjectIDs.firstIndex(of: anchorProjectID),
              let targetIndex = orderedProjectIDs.firstIndex(of: projectID) else {
            selectOnly(projectID)
            return
        }
        let rangeBounds = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selectedProjectIDs = Set(orderedProjectIDs[rangeBounds])
    }

    mutating func clear() {
        selectedProjectIDs = []
        anchorProjectID = nil
    }

    /// Hidden, removed, or filtered projects must not be included in a sidebar action.
    mutating func keepOnly(_ availableProjectIDs: Set<String>) {
        selectedProjectIDs.formIntersection(availableProjectIDs)
        if let anchorProjectID, !availableProjectIDs.contains(anchorProjectID) {
            self.anchorProjectID = nil
        }
    }
}
