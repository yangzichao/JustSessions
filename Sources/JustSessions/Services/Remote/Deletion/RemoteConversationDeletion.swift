import Foundation

struct RemoteConversationDeletion: Sendable {
    let runner: RemoteHostCommandRunner
    let mirror: RemoteSessionMirror

    init(runner: RemoteHostCommandRunner = RemoteHostCommandRunner(), mirror: RemoteSessionMirror = RemoteSessionMirror()) {
        self.runner = runner
        self.mirror = mirror
    }

    static let missingTranscriptExitStatus: Int32 = 3

    func delete(_ conversation: Conversation) throws {
        guard let host = conversation.host.sshDestination,
            conversation.provider.isValidSessionID(conversation.sessionID)
        else {
            throw ConversationDeletionError.invalidSource
        }
        let folders = mirror.savedToolFolders(host: host)
        let command: String
        switch conversation.provider {
        case .claude:
            let projectFolderName = conversation.sourceFile.deletingLastPathComponent().lastPathComponent
            guard Self.isSafeFolderName(projectFolderName) else { throw ConversationDeletionError.invalidSource }
            command = Self.claudeDeletionCommand(
                claudeFolder: folders.shellPath(for: .claude),
                projectFolderName: projectFolderName,
                sessionID: conversation.sessionID
            )
        case .codex:
            command = RemoteCLICommandBuilder.loginShellCommand(
                "codex delete --force \(ShellQuoting.quoted(conversation.sessionID))",
                on: host
            )
        case .kiro where KiroV3Session.isSessionID(conversation.sessionID):
            let sessionFolder = conversation.sourceFile.deletingLastPathComponent()
            let workspaceFolderName = sessionFolder.deletingLastPathComponent().lastPathComponent
            guard KiroV3Session.isMessagesFile(conversation.sourceFile),
                sessionFolder.lastPathComponent == conversation.sessionID,
                Self.isSafeFolderName(workspaceFolderName),
                let metadata = KiroV3SessionMetadata(file: sessionFolder.appendingPathComponent(KiroV3Session.metadataFileName)),
                metadata.sessionID == conversation.sessionID,
                metadata.projectPath == conversation.projectPath,
                conversation.projectPath.hasPrefix("/")
            else { throw ConversationDeletionError.invalidSource }
            command = RemoteKiroConversationDeletion.v3Command(
                sessionID: conversation.sessionID,
                workspaceFolderName: workspaceFolderName,
                projectPath: conversation.projectPath,
                sessionsFolder: folders.shellPath(for: .kiro),
                host: host
            )
        case .kiro:
            let metadataFile = conversation.sourceFile.deletingPathExtension().appendingPathExtension("json")
            guard conversation.sourceFile.lastPathComponent == "\(conversation.sessionID).jsonl",
                let metadata = KiroSessionMetadata(file: metadataFile),
                metadata.sessionID == conversation.sessionID,
                metadata.projectPath == conversation.projectPath,
                conversation.projectPath.hasPrefix("/")
            else { throw ConversationDeletionError.invalidSource }
            command = RemoteKiroConversationDeletion.command(
                sessionID: conversation.sessionID,
                projectPath: conversation.projectPath,
                sessionsFolder: folders.shellPath(for: .kiro),
                host: host
            )
        case .antigravity:
            let configurationDirectory = conversation.sourceFile.deletingLastPathComponent().deletingLastPathComponent()
            _ = try AntigravityDeletionFiles.validated(for: conversation, configurationDirectory: configurationDirectory)
            command = RemoteAntigravityConversationDeletion.command(
                sessionID: conversation.sessionID, projectPath: conversation.projectPath, host: host
            )
        case .pi:
            let names = try RemotePiConversationDeletion.hostFileNames(
                of: conversation,
                piMirrorDirectory: mirror.mirrorDirectory(host: host, provider: .pi)
            )
            command = RemotePiConversationDeletion.command(
                sessionsFolder: folders.path(for: .pi),
                folder: names.folder,
                fileName: names.fileName,
                sessionID: conversation.sessionID
            )
        case .opencode:
            _ = try RemoteOpenCodeConversationDeletion.validatedMirrorDatabase(for: conversation, mirror: mirror, host: host)
            command = RemoteOpenCodeConversationDeletion.command(sessionID: conversation.sessionID, host: host)
        }

        guard let result = runner.run(host, command, 60) else { throw RemoteConversationDeletionError.couldNotRun(host: host) }
        switch result.exitStatus {
        case 0:
            removeMirrorCopies(of: conversation)
        case RemoteHostCommandRunner.connectionFailureExitStatus:
            throw RemoteConversationDeletionError.sshFailed(
                host: host,
                details: SSHConnectionProblem.tellingLine(inOutput: result.output) ?? "exit status \(result.exitStatus)"
            )
        case Self.missingTranscriptExitStatus where [.claude, .kiro, .antigravity, .opencode, .pi].contains(conversation.provider):
            removeMirrorCopies(of: conversation)
        default:
            let details = TerminalEscapeSequences.removed(from: result.output).trimmingCharacters(in: .whitespacesAndNewlines)
            throw RemoteConversationDeletionError.failed(
                host: host,
                details: details.isEmpty ? "exit status \(result.exitStatus)" : String(details.suffix(500))
            )
        }
    }

    private func removeMirrorCopies(of conversation: Conversation) {
        if conversation.provider == .opencode {
            RemoteOpenCodeConversationDeletion.removeMirrorRows(of: conversation.sessionID, from: conversation.sourceFile)
            return
        }
        if conversation.provider == .kiro, KiroV3Session.isMessagesFile(conversation.sourceFile) {
            try? FileManager.default.removeItem(at: conversation.sourceFile.deletingLastPathComponent())
            return
        }
        try? FileManager.default.removeItem(at: conversation.sourceFile)
        if conversation.provider == .kiro {
            try? FileManager.default.removeItem(at: conversation.sourceFile.deletingPathExtension().appendingPathExtension("json"))
        }
        if conversation.provider == .antigravity {
            for file in AntigravityDeletionFiles.databaseFiles(conversation.sourceFile) { try? FileManager.default.removeItem(at: file) }
        }
    }

    static func claudeDeletionCommand(claudeFolder: String, projectFolderName: String, sessionID: String) -> String {
        let script = """
            dir=\(claudeFolder)/projects/\(ShellQuoting.quoted(projectFolderName))
            id=\(ShellQuoting.quoted(sessionID))
            [ -f "$dir/$id.jsonl" ] || exit \(missingTranscriptExitStatus)
            rm -f "$dir/$id.jsonl" && rm -rf "$dir/$id" || exit 1
            index="$dir/sessions-index.json"
            if [ -f "$index" ] && command -v python3 >/dev/null 2>&1; then
              python3 - "$index" "$id" <<'PYTHON'
            import json, os, sys
            path, session_id = sys.argv[1], sys.argv[2]
            with open(path) as file:
                index = json.load(file)
            entries = index.get("entries")
            if isinstance(entries, list):
                remaining = [entry for entry in entries if entry.get("sessionId") != session_id]
                if len(remaining) != len(entries):
                    index["entries"] = remaining
                    with open(path + ".tmp", "w") as file:
                        json.dump(index, file, indent=2, sort_keys=True)
                    os.replace(path + ".tmp", path)
            PYTHON
            fi
            exit 0
            """
        return "sh -c \(ShellQuoting.quoted(script))"
    }

    /// Claude Code names project folders after the path with `/` replaced, so a real one is a single component.
    static func isSafeFolderName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/")
    }
}
