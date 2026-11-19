import Foundation

extension ConversationStore {
    func deletesSessionWhenClosed(_ tab: TerminalSession) -> Bool {
        guard let conversation = tab.conversation else { return tab.deletesSessionWhenClosed }
        return sessionsDeletedWhenTabCloses.isDeletedWhenTabCloses(conversationID: conversation.id)
    }

    func keepSessionAfterClosing(_ tab: TerminalSession) {
        tab.deletesSessionWhenClosed = false
        guard let conversation = tab.conversation else {
            noteTabStateChanged()
            return
        }
        setDeletedWhenTabCloses(false, conversationIDs: [conversation.id])
    }

    func carryDeletionWhenClosed(of tab: TerminalSession, from previousConversationID: String?) {
        guard let conversation = tab.conversation, conversation.id != previousConversationID else { return }
        if let previousConversationID {
            let previousWasDeletedWhenTabCloses = sessionsDeletedWhenTabCloses.isDeletedWhenTabCloses(
                conversationID: previousConversationID
            )
            guard previousWasDeletedWhenTabCloses else { return }
            tab.deletesSessionWhenClosed = false
            setDeletedWhenTabCloses(false, conversationIDs: [previousConversationID])
        } else if tab.deletesSessionWhenClosed {
            setDeletedWhenTabCloses(true, conversationIDs: [conversation.id])
        }
    }

    func closeTabDeletingItsSession(_ id: UUID) {
        guard let tab = terminalSessions.first(where: { $0.id == id }) else { return }
        guard let conversation = tab.conversation.flatMap({ conversationIndex.conversation(withID: $0.id) }) else {
            closingTabsWithoutRemembering { closeTerminal(id, endingTmuxSession: true) }
            return
        }
        closeAndDelete(conversation)
    }
}
