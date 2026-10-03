import Foundation

struct ConversationExportDocument: Sendable {
    struct SessionTranscript: Sendable {
        let selection: ConversationExportSelection
        let transcript: TranscriptContent
    }

    let sessions: [SessionTranscript]

    /// Reads saved messages without the preview's entry or text limits. Remote sessions use their local mirror.
    static func load(_ selections: [ConversationExportSelection]) async throws -> Self {
        guard !selections.isEmpty else { throw ConversationExportError.emptySelection }
        var sessions: [SessionTranscript] = []
        for selection in selections {
            try Task.checkCancellation()
            let transcript: TranscriptContent
            do {
                transcript = try await TranscriptLoader.load(selection.conversation, maximumEntryCount: .max, maximumTextLength: .max)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw ConversationExportError.unreadable(selection, reason: error.localizedDescription)
            }
            guard !transcript.entries.isEmpty else { throw ConversationExportError.noMessages(selection) }
            sessions.append(SessionTranscript(selection: selection, transcript: transcript))
        }
        return Self(sessions: sessions)
    }

    func text(in format: ConversationExportFormat) async throws -> String {
        try Task.checkCancellation()
        return try ConversationExportFormatter.text(for: sessions, in: format)
    }

    func write(to destination: URL, format: ConversationExportFormat) async throws {
        let contents = try await text(in: format)
        try Task.checkCancellation()
        try contents.write(to: destination, atomically: true, encoding: .utf8)
    }

    func suggestedFileName(for format: ConversationExportFormat) -> String {
        let title = sessions.count == 1 ? sessions[0].selection.title : "Conversations"
        let forbiddenCharacters = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:\\"))
        let safeTitle = title.components(separatedBy: forbiddenCharacters).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        let baseName = safeTitle.isEmpty ? "Conversation" : String(safeTitle.prefix(100))
        return baseName + "." + format.fileExtension
    }
}
