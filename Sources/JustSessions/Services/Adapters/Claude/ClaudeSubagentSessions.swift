import Foundation

struct ClaudeSubagentSession: Sendable, Codable {
    let workingDirectory: String?
    let title: String
    /// The model of the first assistant line; a subagent keeps one model while it runs.
    let model: String?
    private static let assistantMarker = Data(#""type":"assistant""#.utf8)

    init(file: URL) {
        var workingDirectory: String?
        var firstPrompt: String?
        var model: String?
        var lineCount = 0
        JSONLinesReader.forEachLeadingLine(in: file, maximumByteCount: ClaudeTranscriptHead.maximumByteCount) { line in
            lineCount += 1
            let needsRecord = workingDirectory == nil || firstPrompt == nil || line.range(of: Self.assistantMarker) != nil
            if needsRecord, let record = ConversationMetadata.object(from: line) {
                workingDirectory = workingDirectory ?? record["cwd"] as? String
                if firstPrompt == nil { firstPrompt = ClaudeUserPromptText.text(ofRecord: record) }
                if model == nil, record["type"] as? String == "assistant" {
                    model = SessionModel(id: (record["message"] as? [String: Any])?["model"] as? String)?.id
                }
            }
            return (workingDirectory == nil || firstPrompt == nil || model == nil)
                && lineCount < ClaudeTranscriptHead.maximumLineCount
        }
        self.model = model
        let metadataFile = file.deletingPathExtension().appendingPathExtension("meta.json")
        let description =
            (try? Data(contentsOf: metadataFile))
            .flatMap(ConversationMetadata.object(from:))?["description"] as? String
        self.workingDirectory = workingDirectory
        title = ConversationMetadata.cleanTitle(
            description.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? firstPrompt,
            fallback: ConversationMetadata.untitledConversationTitle
        )
    }
}

/// Claude Code keeps the transcript of each subagent a session starts as `agent-<agent id>.jsonl` in the session's
/// folder, `<project>/<session id>/subagents/`, and those a workflow starts in folders inside it.
enum ClaudeSubagentSessions {
    static let filePrefix = "agent-"

    static func files(ofSessionID sessionID: String, inProjectDirectory projectDirectory: URL) -> [URL] {
        let folder = projectDirectory.appendingPathComponent(sessionID).appendingPathComponent("subagents")
        guard
            let enumerator = FileManager.default.enumerator(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
        else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { file in
            file.pathExtension == "jsonl" && agentID(of: file) != nil && file.isPlainFileNotLinkOrPipe
        }
    }

    static func agentID(of file: URL) -> String? {
        let name = file.deletingPathExtension().lastPathComponent
        guard name.hasPrefix(filePrefix) else { return nil }
        let agentID = name.dropFirst(filePrefix.count)
        guard !agentID.isEmpty, agentID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return String(agentID)
    }
}
