import Foundation

/// Owned by one deletion worker. Only successfully trashed sessions enter a batch; cancellation flushes it too.
final class ClaudeDeletionIndexBatch {
    static let maximumSessionCount = 32
    private var conversationsByProject: [URL: [Conversation]] = [:]
    private(set) var pendingCount = 0
    private let updateIndex: (Set<String>, URL) throws -> Void

    init(updateIndex: @escaping (Set<String>, URL) throws -> Void = ClaudeConversationIndex.remove) {
        self.updateIndex = updateIndex
    }

    func record(_ conversation: Conversation, in project: URL) {
        conversationsByProject[project, default: []].append(conversation)
        pendingCount += 1
    }

    func flush() -> [ConversationDeletionFailure] {
        let pending = conversationsByProject
        conversationsByProject.removeAll(keepingCapacity: true)
        pendingCount = 0
        var failures: [ConversationDeletionFailure] = []
        for (project, conversations) in pending {
            do {
                // Read afresh so sessions added by the CLI between batches remain in the index.
                try updateIndex(Set(conversations.map(\.sessionID)), project)
            } catch {
                failures += conversations.map {
                    ConversationDeletionFailure(conversation: $0, reason: error.localizedDescription, isStillListed: false)
                }
            }
        }
        return failures
    }
}
