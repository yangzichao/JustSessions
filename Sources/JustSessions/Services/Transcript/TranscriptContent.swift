import Foundation

struct TranscriptContent: Sendable, Equatable {
    let entries: [TranscriptEntry]
    /// Older entries left out so very long sessions stay responsive.
    let omittedEntryCount: Int
    var usesEntryIDsForPositions = false

    func positionID(at offset: Int) -> Int {
        usesEntryIDsForPositions ? entries[offset].id : omittedEntryCount + offset
    }

    var positionIDs: [Int] { entries.indices.map(positionID(at:)) }
    var positionedEntries: [TranscriptPositionedEntry] {
        entries.indices.map { TranscriptPositionedEntry(id: positionID(at: $0), entry: entries[$0]) }
    }
}
