import Foundation

/// What a subagent's Claude Code transcript, and the `.meta.json` beside it, say about it.
struct ClaudeSubagentSession: Sendable, Codable {
    /// The first `cwd` the transcript records.
    let workingDirectory: String?
    /// The task's short description, or else the first line of the prompt the subagent was given. Kept short, since
    /// a session can start thousands of subagents with long prompts.
    let title: String

    /// Reads as far as the first prompt, which a subagent's transcript usually opens with, and the folder it names.
    init(file: URL) {
        var workingDirectory: String?
        var firstPrompt: String?
        var lineCount = 0
        JSONLinesReader.forEachLeadingLine(in: file, maximumByteCount: ClaudeTranscriptHead.maximumByteCount) { line in
            lineCount += 1
            if let record = ConversationMetadata.object(from: line) {
                workingDirectory = workingDirectory ?? record["cwd"] as? String
                if firstPrompt == nil, record["type"] as? String == "user", let message = record["message"] as? [String: Any] {
                    firstPrompt = message["content"] as? String
                }
            }
            return (workingDirectory == nil || firstPrompt == nil) && lineCount < ClaudeTranscriptHead.maximumLineCount
        }
        let metadataFile = file.deletingPathExtension().appendingPathExtension("meta.json")
        let description = (try? Data(contentsOf: metadataFile))
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

    /// The subagent transcripts in the folder of the session with `sessionID`, in any order.
    static func files(ofSessionID sessionID: String, inProjectDirectory projectDirectory: URL) -> [URL] {
        let folder = projectDirectory.appendingPathComponent(sessionID).appendingPathComponent("subagents")
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { file in
            file.pathExtension == "jsonl" && agentID(of: file) != nil
                && (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
        }
    }

    /// The id in an `agent-<id>.jsonl` file's name.
    static func agentID(of file: URL) -> String? {
        let name = file.deletingPathExtension().lastPathComponent
        guard name.hasPrefix(filePrefix) else { return nil }
        let agentID = name.dropFirst(filePrefix.count)
        guard !agentID.isEmpty, agentID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return String(agentID)
    }
}
