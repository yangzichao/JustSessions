import Foundation

struct SessionMessageText: Sendable, Codable, Equatable {
    struct Entry: Sendable, Codable, Equatable {
        let id: Int
        let segments: [String]
    }

    let entries: [Entry]
}
