import Foundation

/// Collects entries while a session file is read, then numbers them and marks where each turn starts.
struct TranscriptBuilder {
    enum EntryKind {
        case userMessage
        case assistantMessage
        case toolCall
        case note
    }

    private enum Speaker {
        case user
        case assistant

        init?(_ content: TranscriptEntry.Content) {
            switch content {
            case .userMessage: self = .user
            case .assistantMessage, .toolCalls: self = .assistant
            case .note: return nil
            }
        }
    }

    private struct PendingEntry {
        var content: TranscriptEntry.Content
        let timestamp: Date?
    }

    let maximumEntryCount: Int
    let maximumTextLength: Int
    private var pendingEntries: [PendingEntry] = []

    init(maximumEntryCount: Int = 2_000, maximumTextLength: Int = 12_000) {
        self.maximumEntryCount = maximumEntryCount
        self.maximumTextLength = maximumTextLength
    }

    mutating func append(_ kind: EntryKind, text: String, timestamp: Date?) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        let limitedText = trimmedText.count > maximumTextLength
            ? String(trimmedText.prefix(maximumTextLength)) + "\n…"
            : trimmedText

        switch kind {
        case .userMessage:
            pendingEntries.append(PendingEntry(content: .userMessage(limitedText), timestamp: timestamp))
        case .assistantMessage:
            pendingEntries.append(PendingEntry(content: .assistantMessage(limitedText), timestamp: timestamp))
        case .note:
            pendingEntries.append(PendingEntry(content: .note(limitedText), timestamp: timestamp))
        case .toolCall:
            if let lastIndex = pendingEntries.indices.last,
               case .toolCalls(let summaries) = pendingEntries[lastIndex].content {
                pendingEntries[lastIndex].content = .toolCalls(summaries + [limitedText])
            } else {
                pendingEntries.append(PendingEntry(content: .toolCalls([limitedText]), timestamp: timestamp))
            }
        }
    }

    /// Keeps the newest entries when the session is longer than `maximumEntryCount`.
    func build() -> TranscriptContent {
        let omittedEntryCount = max(0, pendingEntries.count - maximumEntryCount)
        var entries: [TranscriptEntry] = []
        var previousSpeaker: Speaker?
        for (offset, pendingEntry) in pendingEntries.dropFirst(omittedEntryCount).enumerated() {
            let speaker = Speaker(pendingEntry.content)
            entries.append(TranscriptEntry(
                id: offset,
                content: pendingEntry.content,
                timestamp: pendingEntry.timestamp,
                startsTurn: speaker != nil && speaker != previousSpeaker
            ))
            previousSpeaker = speaker
        }
        return TranscriptContent(entries: entries, omittedEntryCount: omittedEntryCount)
    }
}
