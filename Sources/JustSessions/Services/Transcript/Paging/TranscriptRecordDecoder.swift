import Foundation

struct TranscriptRecordDecoder {
    let provider: ConversationProvider
    let maximumTextLength: Int
    var isSubagentTranscript = false
    var decodesImages = true
    private let jsonDecoder = JSONDecoder()

    func pageEntries(from data: Data?, head: (_ byteCount: Int) throws -> Data) rethrows -> ([TranscriptEntry], Int) {
        if data == nil, provider == .codex, !CodexTranscriptReader.mightContainTranscriptItem(try head(512)) { return ([], 0) }
        return (entries(from: data), data?.count ?? 0)
    }

    func entries(from data: Data?) -> [TranscriptEntry] {
        guard let data else {
            return [TranscriptEntry(id: 0, content: .note("This record is too large to preview."), timestamp: nil, startsTurn: false)]
        }
        var builder = TranscriptBuilder(maximumEntryCount: .max, maximumTextLength: maximumTextLength)
        builder.decodesImages = decodesImages
        if provider == .pi {
            if let entry = try? jsonDecoder.decode(PiSessionEntry.self, from: data) {
                PiTranscriptReader().append(entry, to: &builder)
            }
        } else {
            if provider == .codex, !CodexTranscriptReader.mightContainTranscriptItem(data) { return [] }
            guard let record = ConversationMetadata.object(from: data) else { return [] }
            switch provider {
            case .claude: ClaudeTranscriptReader(includesSidechains: isSubagentTranscript).append(record, to: &builder)
            case .codex: CodexTranscriptReader().append(record, to: &builder)
            case .kiro: KiroTranscriptReader().append(record, to: &builder)
            default: break
            }
        }
        return builder.build().entries
    }
}
