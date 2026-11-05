import Foundation

/// A session or open tab dragged from the sidebar onto the terminals and let go there shows as a tab dragged from the
/// tab bar does: in a split view on the side it was let go on, beside the selected tab or in place of the shown split's
/// pane there, or, let go in the middle, on its own in place of the shown tab. A session with no tab open resumes in a
/// new tab to do so. While no tab is selected, it shows filling the terminals wherever it is let go.
extension ConversationStore {
    /// Where the row would show, let go over the terminals where a tab would show at `pointedPlace`; nil when it can't
    /// show here: a tab that is the selected one or in a split, or a session another window's tab runs, or one that
    /// can't be resumed.
    func dropPlace(for row: SidebarDraggedRow, at pointedPlace: TerminalDropPlace) -> TerminalDropPlace? {
        switch row {
        case .openTab(let tabID):
            guard terminalSessions.contains(where: { $0.id == tabID }) else { return nil }
            return dropPlace(forTab: tabID, at: pointedPlace)
        case .session(let conversation):
            if let tab = openTab(of: conversation) { return dropPlace(forTab: tab.id, at: pointedPlace) }
            guard canLaunch(conversation, action: .resume), runningTerminalInAnotherWindow(for: conversation) == nil else {
                return nil
            }
            return selectedTerminalID == nil ? .wholeArea : pointedPlace
        }
    }

    /// Shows the row where it was let go over the terminals, at `pointedPlace`, unless it can no longer show there.
    func showDroppedRow(_ row: SidebarDraggedRow, at pointedPlace: TerminalDropPlace) {
        guard let place = dropPlace(for: row, at: pointedPlace) else { return }
        switch (row, place) {
        case (.openTab(let tabID), .wholeArea):
            selectTerminal(tabID)
        case (.openTab(let tabID), .split(let side, let orientation)):
            showDroppedTabInSplit(tabID, on: side, orientation: orientation)
        case (.session(let conversation), .wholeArea):
            // As a double-click on it does: it resumes, in its own tab if one is open here.
            resume(conversation)
        case (.session(let conversation), .split(let side, let orientation)):
            // Resumed too, so it leaves the archive also when its tab is already open.
            unarchiveResumableSessions([conversation])
            showDroppedSessionInSplit(conversation, on: side, orientation: orientation)
        }
    }

    private func dropPlace(forTab tabID: UUID, at pointedPlace: TerminalDropPlace) -> TerminalDropPlace? {
        guard selectedTerminalID != nil else { return .wholeArea }
        return canShowDroppedTabs([tabID]) ? pointedPlace : nil
    }

    /// The session's tab in this window: the one running its CLI, or else one whose CLI ended.
    private func openTab(of conversation: Conversation) -> TerminalSession? {
        runningTerminal(for: conversation) ?? terminalSessions.first { $0.conversation?.id == conversation.id }
    }

    /// Shows the session's tab on `side` of a split view, resuming it in a new tab first when none is open.
    private func showDroppedSessionInSplit(
        _ conversation: Conversation,
        on side: TerminalSplit.Side,
        orientation: TerminalSplit.Orientation
    ) {
        if let tab = openTab(of: conversation) {
            showDroppedTabInSplit(tab.id, on: side, orientation: orientation)
            return
        }
        guard let shownTabID = selectedTerminalID else { return }
        launch(conversation, action: .resume)
        // The new tab opens selected, in no split; the tab shown before comes back for it to join.
        guard let resumedTab = runningTerminal(for: conversation), resumedTab.id != shownTabID else { return }
        selectTerminal(shownTabID)
        showDroppedTabInSplit(resumedTab.id, on: side, orientation: orientation)
    }
}
