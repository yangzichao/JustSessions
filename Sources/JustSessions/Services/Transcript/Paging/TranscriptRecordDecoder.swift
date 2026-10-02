import Foundation

struct TranscriptRecordDecoder {
    let provider: ConversationProvider
    let maximumTextLength: Int
    private let jsonDecoder = JSONDecoder()

    func entries(from data: Data?) -> [TranscriptEntry] {
        guard let data else {
            return [TranscriptEntry(id: 0, content: .note("This record is too large to preview."), timestamp: nil, startsTurn: false)]
        }
        var builder = TranscriptBuilder(maximumEntryCount: .max, maximumTextLength: maximumTextLength)
        if provider == .pi {
            if let entry = try? jsonDecoder.decode(PiSessionEntry.self, from: data) {
                PiTranscriptReader().append(entry, to: &builder)
            }
        } else {
            if provider == .codex, !CodexTranscriptReader.mightContainTranscriptItem(data) { return [] }
            guard let record = ConversationMetadata.object(from: data) else { return [] }
            switch provider {
            case .claude: ClaudeTranscriptReader().append(record, to: &builder)
            case .codex: CodexTranscriptReader().append(record, to: &builder)
            case .kiro: KiroTranscriptReader().append(record, to: &builder)
            default: break
            }
        }
        return builder.build().entries
    }
}
