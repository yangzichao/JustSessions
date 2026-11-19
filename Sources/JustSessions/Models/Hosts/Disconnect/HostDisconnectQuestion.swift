import Foundation

struct HostDisconnectQuestion: Identifiable, Equatable, Sendable {
    let id = UUID()
    let host: String
    let question: SeveralTabsClosingQuestion
}
