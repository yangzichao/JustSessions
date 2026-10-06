import Foundation

/// What Find searches in a session's reader, read once from the session: what you wrote, the CLI's replies, and its
/// tool calls, each entry in the segments Find matches, under the ID the reader gives the entry.
struct SessionMessageText: Sendable, Codable, Equatable {
    struct Entry: Sendable, Codable, Equatable {
        /// The reader's ID for the entry, which opens the reader there.
        let id: Int
        let segments: [String]
    }

    let entries: [Entry]
}
