import Foundation

struct HostCheckSession: Equatable, Sendable {
    let provider: ConversationProvider?
    let projectPath: String
    var endedTabScreen: String? = nil
}
