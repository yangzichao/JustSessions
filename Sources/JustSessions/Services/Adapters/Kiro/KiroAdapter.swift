import Foundation

/// Kiro CLI's chat keeps each session as `<id>.json`, its metadata, beside `<id>.jsonl`, its messages, in
/// `sessions/cli` of its home folder (`KIRO_HOME`, or `~/.kiro`).
struct KiroAdapter: ConversationAdapter {
    let sessionsDirectory: URL
    let deletionExecutableURL: URL?
    var provider: ConversationProvider { .kiro }

    static func standardSessionsDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        let kiroHome = environment["KIRO_HOME"].flatMap { $0.hasPrefix("/") ? $0 : nil } ?? homeDirectory + "/.kiro"
        return URL(fileURLWithPath: kiroHome).appendingPathComponent("sessions/cli")
    }

    init(sessionsDirectory: URL = KiroAdapter.standardSessionsDirectory(), deletionExecutableURL: URL? = nil) {
        self.sessionsDirectory = sessionsDirectory
        self.deletionExecutableURL = deletionExecutableURL
    }

    func discover() throws -> [Conversation] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return files.filter { $0.pathExtension == "json" }.compactMap(conversation(describedBy:))
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] {
        switch action {
        case .new: ["chat"]
        case .resume, .branch: ["chat", "--resume-id", conversation.sessionID]
        }
    }

    func delete(_ conversation: Conversation) throws {
        try KiroConversationDeletion(
            sessionsDirectory: sessionsDirectory,
            executableURL: deletionExecutableURL
        ).delete(conversation)
    }

    /// Nil for a session another one started, such as a subagent's, and for one opened but never used, whose
    /// messages file is missing or empty.
    private func conversation(describedBy metadataFile: URL) -> Conversation? {
        let messagesFile = metadataFile.deletingPathExtension().appendingPathExtension("jsonl")
        guard let messagesSize = (try? messagesFile.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, messagesSize > 0,
              let metadata = KiroSessionMetadata(file: metadataFile),
              metadata.createdReason != "subagent",
              provider.isValidSessionID(metadata.sessionID),
              metadataFile.lastPathComponent == "\(metadata.sessionID).json",
              metadata.projectPath.hasPrefix("/") else { return nil }
        let title = ConversationMetadata.cleanTitle(
            metadata.title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ?? KiroFirstPrompt.find(in: messagesFile),
            fallback: ConversationMetadata.untitledConversationTitle
        )
        return Conversation(
            provider: provider,
            sessionID: metadata.sessionID,
            projectPath: metadata.projectPath,
            suggestedTitle: title,
            updatedAt: max(metadata.updatedAt ?? .distantPast, ConversationMetadata.fileModificationDate(messagesFile)),
            sourceFile: messagesFile
        )
    }
}
