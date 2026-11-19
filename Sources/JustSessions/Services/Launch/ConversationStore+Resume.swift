import Foundation

extension ConversationStore {
    func resume(_ conversation: Conversation, appendedArguments: [String] = []) {
        unarchiveResumableSessions([conversation])
        launch(conversation, action: .resume, appendedArguments: appendedArguments)
    }

    func resume(_ conversations: [Conversation]) {
        unarchiveResumableSessions(conversations)
        launch(conversations, action: .resume)
    }

    func unarchiveResumableSessions(_ conversations: [Conversation]) {
        setArchived(false, conversations: conversations.filter { canLaunch($0, action: .resume) })
    }
}
