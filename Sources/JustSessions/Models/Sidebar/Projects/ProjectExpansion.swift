import Foundation

/// Which projects in the sidebar show their sessions. While searching, every project shows its matches.
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

    /// Opens each of these projects that is closed; open ones stay open.
    mutating func expand(_ projectIDs: [String]) {
        expandedProjectIDs.formUnion(projectIDs)
    }
}
