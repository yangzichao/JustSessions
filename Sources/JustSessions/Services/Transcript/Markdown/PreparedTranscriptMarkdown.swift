import Foundation

/// Immutable, font-independent work shared by rendering and Find. Pages prepare it on their reader actor.
struct PreparedTranscriptMarkdown: Sendable, Equatable {
    let blocks: [TranscriptMarkdownBlock]
    let segmentStarts: [Int: Int]
    let searchSegments: [String]

    init(text: String) {
        blocks = TranscriptMarkdownParser.blocks(from: text)
        segmentStarts = TranscriptSearchSegments.startingIndices(in: blocks)
        searchSegments = blocks.flatMap(TranscriptSearchSegments.texts(in:))
    }
}

extension TranscriptPage {
    func preparingMarkdown() throws -> Self {
        let preparedEntries = try entries.map { entry in
            try Task.checkCancellation()
            var entry = entry
            if case .assistantMessage(let text) = entry.content {
                entry.markdown = PreparedTranscriptMarkdown(text: text)
            }
            return entry
        }
        return Self(entries: preparedEntries, records: records, totalRecordCount: totalRecordCount, decodedByteCount: decodedByteCount)
    }
}
