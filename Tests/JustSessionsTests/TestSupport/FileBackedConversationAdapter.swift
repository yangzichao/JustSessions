import Foundation

@testable import JustSessions

struct FileBackedConversationAdapter: ConversationAdapter {
    struct RefusedDeletion: LocalizedError {
        let reason: String
        var errorDescription: String? { reason }
    }

    let provider: ConversationProvider
    let conversations: [Conversation]
    var refusedSessionIDs: Set<String> = []
    var refusalReason = "The tool refused to delete this session."
    var removesRefusedFiles = false

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        try cancellation.checkCancellation()
        let found = conversations.filter {
            !cancellation.isCancelled && $0.provider == provider
                && FileManager.default.fileExists(atPath: $0.sourceFile.path)
        }
        try cancellation.checkCancellation()
        return found
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }

    func delete(_ conversation: Conversation) throws {
        if refusedSessionIDs.contains(conversation.sessionID) {
            if removesRefusedFiles { try FileManager.default.removeItem(at: conversation.sourceFile) }
            throw RefusedDeletion(reason: refusalReason)
        }
        try FileManager.default.removeItem(at: conversation.sourceFile)
    }
}
