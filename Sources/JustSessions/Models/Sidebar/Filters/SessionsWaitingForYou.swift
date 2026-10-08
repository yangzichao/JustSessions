import Foundation

/// The sessions whose CLI waits on you, as the Waiting for you filter keeps them: listed sessions by id, and tabs by
/// id, so a new session's tab counts before its session is listed. See `WaitingForYou`.
struct SessionsWaitingForYou: Equatable {
    var conversationIDs: Set<String> = []
    var terminalIDs: Set<UUID> = []
}
