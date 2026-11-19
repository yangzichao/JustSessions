import Foundation

struct SessionMessageMatch: Sendable, Equatable {
    let entryID: Int
    let snippet: SessionMessageSnippet
}
