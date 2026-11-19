import Foundation

extension ConversationStore {
    func link(_ session: TerminalSession, to conversation: Conversation) {
        if session.conversation?.id != conversation.id { session.titleRefreshCount = 0 }
        let previousConversationID = session.conversation?.id
        session.synchronize(conversation: conversation, displayTitle: title(for: conversation))
        carryDeletionWhenClosed(of: session, from: previousConversationID)
        adoptSessionTmuxName(for: session)
        persistOpenTabs()
        noteTabStateChanged()
        windowRegistry.tabsChanged(in: self)
    }
}
