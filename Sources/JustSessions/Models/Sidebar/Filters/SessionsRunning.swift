import Foundation

struct SessionsRunning: Equatable {
    var conversationIDs: Set<String> = []
    var terminalIDs: Set<UUID> = []
}
