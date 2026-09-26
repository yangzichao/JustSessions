import Foundation
@testable import JustSessions

/// Lists those of `conversations` whose files exist and deletes one by removing its file, as the real adapters
/// work on session files. A session in `refusedSessionIDs` is refused with `refusalReason` instead.
struct FileBackedConversationAdapter: ConversationAdapter {
    struct RefusedDeletion: LocalizedError {
        let reason: String
        var errorDescription: String? { reason }
    }

    let provider: ConversationProvider
    let conversations: [Conversation]
    var refusedSessionIDs: Set<String> = []
    var refusalReason = "The tool refused to delete this session."
    /// Removes a refused session's file anyway, like a tool that deletes the file but then fails to update its index.
    var removesRefusedFiles = false

    func discover() throws -> [Conversation] {
        conversations.filter { $0.provider == provider && FileManager.default.fileExists(atPath: $0.sourceFile.path) }
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
