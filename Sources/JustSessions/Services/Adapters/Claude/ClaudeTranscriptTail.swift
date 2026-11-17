import Foundation

/// What the last lines of a Claude Code transcript say about its session, found without reading the whole file.
struct ClaudeTranscriptTail: Sendable, Codable {
    static let maximumByteCount = 262_144
    /// Bytes every `relocated` line holds. Once the timestamp and title are known, only lines holding them are parsed.
    private static let relocatedWorkingDirectoryKey = Data(#""relocatedCwd""#.utf8)
    /// Bytes every assistant line holds, with the model that wrote it.
    private static let modelKey = Data(#""model""#.utf8)
    /// Bytes every `ai-title` line holds.
    private static let aiTitleKey = Data(#""aiTitle""#.utf8)

    /// The `timestamp` of the last line that has one.
    private(set) var latestTimestamp: Date?
    /// The title from the last `custom-title` line that has one.
    private(set) var latestCustomTitle: String?
    /// The title from the last `ai-title` line: the one Claude Code generates for a session, and rewrites as the
    /// session goes on.
    private(set) var latestAITitle: String?
    /// The `relocatedCwd` of the last `relocated` line: the folder `/cd` moved the session to. Claude Code moves the
    /// transcript into that folder's project directory and reads the session's folder from here, ahead of any `cwd`,
    /// which also changes whenever its shell changes directory.
    private(set) var relocatedWorkingDirectory: String?
    /// The `message.model` of the last assistant line that names a model, `<synthetic>` left out.
    private(set) var latestModel: String?

    init(file: URL) {
        self.init(lines: JSONLinesReader.trailingLines(in: file, maximumByteCount: Self.maximumByteCount))
    }

    /// `lines` are oldest first, as they are in the file.
    init(lines: [Data]) {
        for line in lines.reversed() {
            if latestTimestamp != nil, latestCustomTitle != nil,
               latestAITitle != nil || line.range(of: Self.aiTitleKey) == nil,
               line.range(of: Self.relocatedWorkingDirectoryKey) == nil,
               latestModel != nil || line.range(of: Self.modelKey) == nil { continue }
            guard let record = ConversationMetadata.object(from: line) else { continue }
            if latestTimestamp == nil {
                latestTimestamp = ConversationMetadata.date(record["timestamp"])
            }
            if latestCustomTitle == nil, record["type"] as? String == "custom-title" {
                latestCustomTitle = record["customTitle"] as? String
            }
            if latestAITitle == nil, record["type"] as? String == "ai-title" {
                latestAITitle = record["aiTitle"] as? String
            }
            if relocatedWorkingDirectory == nil, record["type"] as? String == "relocated" {
                relocatedWorkingDirectory = record["relocatedCwd"] as? String
            }
            if latestModel == nil, record["type"] as? String == "assistant" {
                latestModel = SessionModel(id: (record["message"] as? [String: Any])?["model"] as? String)?.id
            }
            if latestTimestamp != nil, latestCustomTitle != nil, relocatedWorkingDirectory != nil, latestModel != nil { break }
        }
    }
}
