import Foundation

/// The sessions whose CLI runs, as the Running filter keeps them: listed sessions by id, and tabs by id, so a new
/// session's tab counts before its session is listed. See `ConversationStore.sessionsRunning`.
struct SessionsRunning: Equatable {
    var conversationIDs: Set<String> = []
    var terminalIDs: Set<UUID> = []
}
