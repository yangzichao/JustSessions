import Foundation

struct ProjectExpansion: Equatable {
    private(set) var expandedProjectIDs: Set<String> = []

    func isExpanded(_ projectID: String, whileSearching isSearching: Bool) -> Bool {
        isSearching || expandedProjectIDs.contains(projectID)
    }

    mutating func toggle(_ projectID: String) {
        if expandedProjectIDs.remove(projectID) == nil {
            expandedProjectIDs.insert(projectID)
        }
    }

    mutating func expand(_ projectIDs: [String]) {
        expandedProjectIDs.formUnion(projectIDs)
    }
}
