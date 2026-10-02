import Foundation

/// Offsets refer to the displayed text, after Markdown formatting has been removed.
struct TranscriptSearchMatch: Equatable, Sendable {
    let entryIndex: Int
    let segmentIndex: Int
    let range: NSRange
}
