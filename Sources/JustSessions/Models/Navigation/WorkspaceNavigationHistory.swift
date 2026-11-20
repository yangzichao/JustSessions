struct WorkspaceNavigationHistory: Equatable {
    static let maximumEntryCount = 50

    private(set) var entries: [WorkspaceLocation] = []
    private(set) var currentIndex: Int?

    mutating func record(_ location: WorkspaceLocation) {
        if let currentIndex, entries[currentIndex] == location { return }
        entries.removeSubrange((currentIndex.map { $0 + 1 } ?? 0)...)
        entries.append(location)
        if entries.count > Self.maximumEntryCount {
            entries.removeFirst(entries.count - Self.maximumEntryCount)
        }
        currentIndex = entries.count - 1
    }

    mutating func replaceCurrent(with location: WorkspaceLocation) {
        guard let currentIndex else { return record(location) }
        entries[currentIndex] = location
    }

    func backEntryIndices(shown: WorkspaceLocation?, canShow: (WorkspaceLocation) -> Bool) -> [Int] {
        guard let currentIndex else { return [] }
        return stride(from: currentIndex, through: 0, by: -1).filter { isDestination(at: $0, shown: shown, canShow: canShow) }
    }

    func forwardEntryIndices(shown: WorkspaceLocation?, canShow: (WorkspaceLocation) -> Bool) -> [Int] {
        guard let currentIndex else { return [] }
        return (currentIndex + 1..<entries.count).filter { isDestination(at: $0, shown: shown, canShow: canShow) }
    }

    mutating func moveBeforeShowing(entryAt index: Int) {
        guard entries.indices.contains(index) else { return }
        currentIndex = index
    }

    private func isDestination(at index: Int, shown: WorkspaceLocation?, canShow: (WorkspaceLocation) -> Bool) -> Bool {
        entries[index] != shown && canShow(entries[index])
    }
}
