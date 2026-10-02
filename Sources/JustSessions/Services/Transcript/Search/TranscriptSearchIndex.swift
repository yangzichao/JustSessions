import Foundation

/// A temporary index of this reader's displayed entries; no files or global history index are written.
struct TranscriptSearchIndex: Sendable {
    private struct Segment: Sendable {
        let entryIndex: Int
        let segmentIndex: Int
        let text: String
    }

    private let segments: [Segment]

    init(transcript: TranscriptContent) throws {
        var segments: [Segment] = []
        for (entryOffset, entry) in transcript.entries.enumerated() {
            try Task.checkCancellation()
            segments += TranscriptSearchSegments.texts(in: entry.content).enumerated().map { segmentIndex, text in
                Segment(entryIndex: transcript.positionID(at: entryOffset), segmentIndex: segmentIndex, text: text)
            }
        }
        self.segments = segments
    }

    func matches(for query: String) throws -> [TranscriptSearchMatch] {
        guard !query.isEmpty else { return [] }
        var matches: [TranscriptSearchMatch] = []
        for segment in segments {
            try Task.checkCancellation()
            matches += TranscriptTextSearch.ranges(of: query, in: segment.text).map {
                TranscriptSearchMatch(entryIndex: segment.entryIndex, segmentIndex: segment.segmentIndex, range: $0)
            }
        }
        return matches
    }
}
