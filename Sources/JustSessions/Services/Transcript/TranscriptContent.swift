import Foundation

struct TranscriptContent: Sendable, Equatable {
    let entries: [TranscriptEntry]
    /// Older entries left out so very long sessions stay responsive.
    let omittedEntryCount: Int
}
