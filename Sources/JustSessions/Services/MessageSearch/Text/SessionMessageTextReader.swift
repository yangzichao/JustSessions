import Foundation

/// Reads a whole session the way its reader pages through it, keeping the text of what you wrote, the CLI's replies,
/// and its tool calls. Notes, such as one for a record too large to show, and images are left out. Images are not even
/// decoded: their entries only hold their place, so every other entry keeps the ID the reader gives it.
enum SessionMessageTextReader {
    /// The reader's own cuts of long messages and large records, so a search never finds text the reader leaves out,
    /// in pages far larger than the reader's, as a session is read from start to end in one go.
    static let wholeSessionLimits = TranscriptPageLimits(
        targetEntryCount: 5_000, maximumRecordCount: 50_000, targetByteCount: 64 << 20
    )

    static func read(_ conversation: Conversation, limits: TranscriptPageLimits = wholeSessionLimits) async throws -> SessionMessageText {
        let source = TranscriptPageSource(
            file: conversation.sourceFile, provider: conversation.provider, sessionID: conversation.sessionID, limits: limits,
            decodesImages: false
        )
        var entries: [SessionMessageText.Entry] = []
        var request = TranscriptPageRequest.first
        while true {
            let page = try await source.read(request)
            entries += page.entries.compactMap(searchedEntry)
            guard page.hasLater else { return SessionMessageText(entries: entries) }
            request = .after(page.records.upperBound)
        }
    }

    private static func searchedEntry(_ entry: TranscriptEntry) -> SessionMessageText.Entry? {
        switch entry.content {
        case .userMessage, .assistantMessage, .toolCalls:
            let segments = TranscriptSearchSegments.texts(in: entry)
            return segments.isEmpty ? nil : SessionMessageText.Entry(id: entry.id, segments: segments)
        case .note, .userImage, .toolResultImage:
            return nil
        }
    }
}
