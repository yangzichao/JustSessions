import Foundation

struct TranscriptSearchMatch: Equatable, Sendable {
    let entryIndex: Int
    let segmentIndex: Int
    let range: NSRange
}
