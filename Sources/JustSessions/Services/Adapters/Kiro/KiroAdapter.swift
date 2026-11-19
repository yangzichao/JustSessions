import Foundation

/// Kiro CLI's chat keeps each session as `<id>.json`, its metadata, beside `<id>.jsonl`, its messages, in
/// `sessions/cli` of its home folder (`KIRO_HOME`, or `~/.kiro`). Its V3 engine keeps each in a folder of its own under
/// `sessions` instead; see `KiroV3Session`. Both are listed.
struct KiroAdapter: ConversationAdapter {
    let sessionsDirectory: URL
    /// V3's sessions: `sessions/<workspace hash>/sess_<uuid>/`. Nil reads V2's alone.
    let v3SessionsDirectory: URL?
    let deletionExecutableURL: URL?
    var provider: ConversationProvider { .kiro }

    static func standardSessionsDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        let kiroHome = environment["KIRO_HOME"].flatMap { $0.hasPrefix("/") ? $0 : nil } ?? homeDirectory + "/.kiro"
        return URL(fileURLWithPath: kiroHome).appendingPathComponent("sessions/cli")
    }

    /// With the standard folders, V3's sessions are read beside V2's; a `sessionsDirectory` of your own reads V2's
    /// alone unless `v3SessionsDirectory` is given too.
    init(sessionsDirectory: URL? = nil, v3SessionsDirectory: URL? = nil, deletionExecutableURL: URL? = nil) {
        let standard = KiroAdapter.standardSessionsDirectory()
        self.sessionsDirectory = sessionsDirectory ?? standard
        self.v3SessionsDirectory =
            v3SessionsDirectory
            ?? (sessionsDirectory == nil ? KiroV3Session.sessionsRoot(besideClassicDirectory: standard) : nil)
        self.deletionExecutableURL = deletionExecutableURL
    }

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        try cancellation.checkCancellation()
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: sessionsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        var conversations = files.filter { $0.pathExtension == "json" }.compactMap {
            cancellation.isCancelled ? nil : conversation(describedBy: $0)
        }
        try cancellation.checkCancellation()
        conversations += v3Conversations(cancellation: cancellation)
        try cancellation.checkCancellation()
        return conversations
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] {
        switch action {
        case .new: ["chat"]
        case .resume, .branch:
            // V2 can't resume a V3 session, and Kiro CLI 2.16 runs V2 unless told otherwise.
            ["chat"] + (KiroV3Session.isSessionID(conversation.sessionID) ? KiroV3Session.engineArguments : [])
                + ["--resume-id", conversation.sessionID]
        }
    }

    func delete(_ conversation: Conversation) throws {
        try KiroConversationDeletion(
            sessionsDirectory: sessionsDirectory,
            v3SessionsDirectory: v3SessionsDirectory,
            executableURL: deletionExecutableURL
        ).delete(conversation)
    }

    /// Each workspace's `sess_<uuid>` folders under `v3SessionsDirectory`, `sessions/cli` aside.
    private func v3Conversations(cancellation: ConversationDiscoveryCancellation) -> [Conversation] {
        let fileManager = FileManager.default
        guard let v3SessionsDirectory,
            let workspaces = try? fileManager.contentsOfDirectory(
                at: v3SessionsDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            )
        else { return [] }
        var conversations: [Conversation] = []
        for workspace in workspaces where workspace.lastPathComponent != sessionsDirectory.lastPathComponent {
            guard
                let folders = try? fileManager.contentsOfDirectory(
                    at: workspace, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
                )
            else { continue }
            for folder in folders where KiroV3Session.isSessionID(folder.lastPathComponent) {
                guard !cancellation.isCancelled else { return conversations }
                if let conversation = v3Conversation(in: folder) { conversations.append(conversation) }
            }
        }
        return conversations
    }

    /// Nil for a subagent's session, one Kiro hasn't written a message to (it writes `messages.jsonl` only then), and
    /// one whose metadata names another session or a relative folder.
    private func v3Conversation(in folder: URL) -> Conversation? {
        let messagesFile = folder.appendingPathComponent(KiroV3Session.messagesFileName)
        guard let messagesSize = (try? messagesFile.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, messagesSize > 0,
            let metadata = KiroV3SessionMetadata(file: folder.appendingPathComponent(KiroV3Session.metadataFileName)),
            metadata.sessionID == folder.lastPathComponent,
            !metadata.isSubagentSession,
            metadata.projectPath.hasPrefix("/")
        else { return nil }
        return Conversation(
            provider: provider,
            sessionID: metadata.sessionID,
            projectPath: metadata.projectPath,
            suggestedTitle: ConversationMetadata.cleanTitle(
                metadata.title ?? KiroFirstPrompt.find(in: messagesFile),
                fallback: ConversationMetadata.untitledConversationTitle
            ),
            updatedAt: max(metadata.updatedAt ?? .distantPast, ConversationMetadata.fileModificationDate(messagesFile)),
            sourceFile: messagesFile
        )
    }

    /// Nil for a session another one started, such as a subagent's, which names its parent, and for one opened but never
    /// used, whose messages file is missing or empty. `session_created_reason` is `subagent` for main sessions too
    /// (`KiroSessionMetadata.createdReason`), so it doesn't hide one.
    private func conversation(describedBy metadataFile: URL) -> Conversation? {
        let messagesFile = metadataFile.deletingPathExtension().appendingPathExtension("jsonl")
        guard let messagesSize = (try? messagesFile.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, messagesSize > 0,
            let metadata = KiroSessionMetadata(file: metadataFile),
            metadata.parentSessionID == nil,
            provider.isValidSessionID(metadata.sessionID),
            metadataFile.lastPathComponent == "\(metadata.sessionID).json",
            metadata.projectPath.hasPrefix("/")
        else { return nil }
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
