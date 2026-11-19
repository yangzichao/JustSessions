import Foundation

struct RemoteSessionCopyStep: Equatable, Sendable {
    let provider: ConversationProvider
    let number: Int
    let count: Int

    var isLast: Bool { number == count }
}
