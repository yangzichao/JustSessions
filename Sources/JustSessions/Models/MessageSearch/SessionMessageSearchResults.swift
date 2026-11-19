import Foundation

struct SessionMessageSearchResults: Sendable, Equatable {
    let query: String
    let matchesByConversationID: [String: SessionMessageMatch]

    static let none = SessionMessageSearchResults(query: "", matchesByConversationID: [:])
}
