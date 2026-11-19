import Foundation

struct TranscriptMatchReveal: Equatable {
    let id = UUID()
    let conversationID: String
    let entryID: Int
    let query: String
}
