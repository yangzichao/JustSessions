import Foundation

struct TranscriptRecordDecoder {
    let provider: ConversationProvider
    let maximumTextLength: Int
    /// Reads a subagent's transcript; see `ClaudeTranscriptReader.includesSidechains`.
    var isSubagentTranscript = false
    /// Off when only the text is read, as for message search: images become `TranscriptImage.unread`.
    var readsImageData = true
    private let jsonDecoder = JSONDecoder()

    func entries(from data: Data?) -> [TranscriptEntry] {
        guard let data else {
            return [TranscriptEntry(id: 0, content: .note("This record is too large to preview."), timestamp: nil, startsTurn: false)]
        }
        var builder = TranscriptBuilder(maximumEntryCount: .max, maximumTextLength: maximumTextLength)
        if provider == .pi {
            if let entry = try? jsonDecoder.decode(PiSessionEntry.self, from: data) {
                PiTranscriptReader(readsImageData: readsImageData).append(entry, to: &builder)
            }
        } else {
            if provider == .codex, !CodexTranscriptReader.mightContainTranscriptItem(data) { return [] }
            guard let record = ConversationMetadata.object(from: data) else { return [] }
            switch provider {
            case .claude:
                ClaudeTranscriptReader(includesSidechains: isSubagentTranscript, readsImageData: readsImageData).append(record, to: &builder)
            case .codex: CodexTranscriptReader(readsImageData: readsImageData).append(record, to: &builder)
            case .kiro: KiroTranscriptReader().append(record, to: &builder)
            default: break
            }
        }
        return builder.build().entries
    }
}
