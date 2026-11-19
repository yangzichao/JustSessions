import Foundation

struct UnlistedClaudeSession: Equatable {
    let sessionID: String
    let movedAt: Date
    var refreshRequestedAt: Date?
    var terminalTitleAtRequest: String?
    var chosenName: String?
}
