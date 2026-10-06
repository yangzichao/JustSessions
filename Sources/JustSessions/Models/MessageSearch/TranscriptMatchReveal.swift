import Foundation

/// Opens a session's reader at a match that a search through every session's messages found, with Find showing the
/// searched text there. Each click on a session row makes a new one, so clicking the row again shows the match again.
struct TranscriptMatchReveal: Equatable {
    let id = UUID()
    let conversationID: String
    /// The reader's ID for the entry with the match.
    let entryID: Int
    let query: String
}
