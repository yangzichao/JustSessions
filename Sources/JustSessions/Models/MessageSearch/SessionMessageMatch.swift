import Foundation

/// The first entry of a session with the searched text, for the session's sidebar row and to open its reader there.
struct SessionMessageMatch: Sendable, Equatable {
    /// The reader's ID for the entry.
    let entryID: Int
    let snippet: SessionMessageSnippet
}
