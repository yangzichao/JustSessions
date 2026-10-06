import Foundation

/// What a search through every session's messages found for one query: each matching session's first match, by
/// session ID.
struct SessionMessageSearchResults: Sendable, Equatable {
    let query: String
    let matchesByConversationID: [String: SessionMessageMatch]

    static let none = SessionMessageSearchResults(query: "", matchesByConversationID: [:])
}
