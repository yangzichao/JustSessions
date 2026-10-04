import Foundation

/// A pane layout as the quit saves it: docked tabs by their place in the saved tab order, because tab ids do not
/// survive a relaunch, and previews by session id, which does.
indirect enum SavedPaneLayout: Codable, Equatable {
    case selection
    case tab(Int)
    case preview(String)
    case split(isHorizontal: Bool, fraction: Double, leading: SavedPaneLayout, trailing: SavedPaneLayout)

    /// Nil for a layout with nothing to save: the unsplit workspace, or one whose docked tabs all lack a saved
    /// place, like a New session tab whose session was never known. A split left with one side collapses, as when
    /// such a pane closes.
    init?(layout: WorkspacePaneLayout, savedPositionsByTabID: [UUID: Int]) {
        guard let saved = Self.saved(layout, savedPositionsByTabID), saved != .selection else { return nil }
        self = saved
    }

    /// The layout this restores to once its tabs reopened. Tabs that never reopened and sessions no longer
    /// listed lose their panes; anything unexpected in the saved data restores the unsplit workspace.
    func restored(tabIDsBySavedPosition: [Int: UUID], listedConversationIDs: Set<String>) -> WorkspacePaneLayout {
        guard let layout = Self.restoredLayout(self, tabIDsBySavedPosition, listedConversationIDs) else {
            return .selectionOnly
        }
        let panes = layout.panes
        // Hand-edited or corrupt defaults could duplicate panes or drop the selection; never render that.
        guard Set(panes).count == panes.count, panes.filter({ $0 == .selection }).count == 1 else {
            return .selectionOnly
        }
        return layout
    }

    /// Whether a docked tab is saved at one of these places, so restoring waits for tabs that may still reopen.
    func referencesTab(in savedPositions: Set<Int>) -> Bool {
        switch self {
        case .selection, .preview: false
        case .tab(let position): savedPositions.contains(position)
        case .split(_, _, let leading, let trailing):
            leading.referencesTab(in: savedPositions) || trailing.referencesTab(in: savedPositions)
        }
    }

    /// Whether a previewed session is not listed yet, so restoring can wait for the first listing at launch.
    func referencesPreview(notIn conversationIDs: Set<String>) -> Bool {
        switch self {
        case .selection, .tab: false
        case .preview(let id): !conversationIDs.contains(id)
        case .split(_, _, let leading, let trailing):
            leading.referencesPreview(notIn: conversationIDs) || trailing.referencesPreview(notIn: conversationIDs)
        }
    }

    private static func saved(_ layout: WorkspacePaneLayout, _ positions: [UUID: Int]) -> SavedPaneLayout? {
        switch layout {
        case .pane(.selection):
            return .selection
        case .pane(.terminal(let id)):
            return positions[id].map { .tab($0) }
        case .pane(.preview(let id)):
            return .preview(id)
        case .split(let split):
            let leading = saved(split.leading, positions)
            let trailing = saved(split.trailing, positions)
            guard let leading else { return trailing }
            guard let trailing else { return leading }
            return .split(isHorizontal: split.isHorizontal, fraction: split.fraction, leading: leading, trailing: trailing)
        }
    }

    private static func restoredLayout(
        _ saved: SavedPaneLayout,
        _ tabIDs: [Int: UUID],
        _ conversationIDs: Set<String>
    ) -> WorkspacePaneLayout? {
        switch saved {
        case .selection:
            return .pane(.selection)
        case .tab(let position):
            return tabIDs[position].map { .pane(.terminal($0)) }
        case .preview(let id):
            return conversationIDs.contains(id) ? .pane(.preview(id)) : nil
        case .split(let isHorizontal, let fraction, let savedLeading, let savedTrailing):
            let leading = restoredLayout(savedLeading, tabIDs, conversationIDs)
            let trailing = restoredLayout(savedTrailing, tabIDs, conversationIDs)
            guard let leading else { return trailing }
            guard let trailing else { return leading }
            return .split(WorkspacePaneSplit(isHorizontal: isHorizontal, fraction: fraction, leading: leading, trailing: trailing))
        }
    }
}
