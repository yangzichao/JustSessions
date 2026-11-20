import Foundation

extension ConversationStore {
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

    func showDroppedRow(_ row: SidebarDraggedRow, at pointedPlace: TerminalDropPlace) {
        guard let place = dropPlace(for: row, at: pointedPlace) else { return }
        switch (row, place) {
        case (.openTab(let tabID), .wholeArea):
            selectTerminal(tabID)
        case (.openTab(let tabID), .split(let side, let orientation)):
            showDroppedTabInSplit(tabID, on: side, orientation: orientation)
        case (.session(let conversation), .wholeArea):
            resume(conversation)
        case (.session(let conversation), .split(let side, let orientation)):
            resumeDroppedSessionInSplit(conversation, on: side, orientation: orientation)
        }
    }

    private func dropPlace(forTab tabID: UUID, at pointedPlace: TerminalDropPlace) -> TerminalDropPlace? {
        guard selectedTerminalID != nil else { return .wholeArea }
        return canShowDroppedTabs([tabID]) ? pointedPlace : nil
    }

    private func openTab(of conversation: Conversation) -> TerminalSession? {
        runningTerminal(for: conversation) ?? terminalSessions.first { $0.conversation?.id == conversation.id }
    }

    private func resumeDroppedSessionInSplit(
        _ conversation: Conversation,
        on side: TerminalSplit.Side,
        orientation: TerminalSplit.Orientation
    ) {
        unarchiveResumableSessions([conversation])
        if let tab = openTab(of: conversation) {
            showDroppedTabInSplit(tab.id, on: side, orientation: orientation)
            return
        }
        guard let tabShownBeforeTheDrop = selectedTerminalID else { return }
        launch(conversation, action: .resume)
        guard let resumedTabSelectedOnItsOwn = runningTerminal(for: conversation),
            resumedTabSelectedOnItsOwn.id != tabShownBeforeTheDrop
        else { return }
        selectTerminal(tabShownBeforeTheDrop)
        showDroppedTabInSplit(resumedTabSelectedOnItsOwn.id, on: side, orientation: orientation)
    }
}
