import Foundation

enum TranscriptPageAssembler {
    static func entries(in records: [(Int, [TranscriptEntry])], maximumMergedToolCallCount: Int = 50) -> [TranscriptEntry] {
        var entries: [TranscriptEntry] = []
        for (record, parts) in records.sorted(by: { $0.0 < $1.0 }) {
            for (part, entry) in parts.enumerated() {
                let identifier = TranscriptPageIdentity.entryID(record: record, part: part)
                if case .toolCalls(let summaries) = entry.content, let previous = entries.last,
                    case .toolCalls(let earlierSummaries) = previous.content,
                    earlierSummaries.count + summaries.count <= maximumMergedToolCallCount
                {
                    entries[entries.count - 1] = TranscriptEntry(
                        id: previous.id, content: .toolCalls(earlierSummaries + summaries),
                        timestamp: previous.timestamp, startsTurn: previous.startsTurn
                    )
                } else {
                    entries.append(
                        TranscriptEntry(id: identifier, content: entry.content, timestamp: entry.timestamp, startsTurn: entry.startsTurn))
                }
            }
        }
        return entries
    }

    static func speaker(of entry: TranscriptEntry) -> Int? {
        switch entry.content {
        case .userMessage, .userImage: 0
        case .assistantMessage, .toolCalls, .toolResultImage: 1
        case .note: nil
        }
    }

    static func transcript(pages: [TranscriptPage]) -> TranscriptContent {
        var previousSpeaker = pages.first?.precedingSpeaker
        let entries = pages.flatMap(\.entries).map { entry in
            let speaker = speaker(of: entry)
            defer { previousSpeaker = speaker }
            return TranscriptEntry(
                id: entry.id, content: entry.content, timestamp: entry.timestamp,
                startsTurn: speaker != nil && speaker != previousSpeaker, markdown: entry.markdown)
        }
        return TranscriptContent(entries: entries, omittedEntryCount: 0, usesEntryIDsForPositions: true)
    }
}
