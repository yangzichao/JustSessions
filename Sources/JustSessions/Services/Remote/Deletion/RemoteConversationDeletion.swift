import Foundation

/// Deletes a session on its remote host over SSH. Remote hosts have no Trash, so this is permanent.
/// Claude Code and Antigravity lose their stored history and index entry; Codex and Kiro use their native CLIs;
/// Pi loses its session file and the folder beside it.
struct RemoteConversationDeletion {
    let runner: RemoteHostCommandRunner
    /// Where the host's sessions were copied, so a Pi session's file is found relative to that host's Pi mirror.
    let mirror: RemoteSessionMirror

    init(runner: RemoteHostCommandRunner = RemoteHostCommandRunner(), mirror: RemoteSessionMirror = RemoteSessionMirror()) {
        self.runner = runner
        self.mirror = mirror
    }

    /// Exit status of a deletion script when the transcript is already gone.
    static let missingTranscriptExitStatus: Int32 = 3

    func delete(_ conversation: Conversation) throws {
        guard let host = conversation.host.sshDestination,
              ConversationMetadata.isValidSessionID(conversation.sessionID) else {
            throw ConversationDeletionError.invalidSource
        }
        let command: String
        switch conversation.provider {
        case .claude:
            let projectFolderName = conversation.sourceFile.deletingLastPathComponent().lastPathComponent
            guard Self.isSafeFolderName(projectFolderName) else { throw ConversationDeletionError.invalidSource }
            command = Self.claudeDeletionCommand(projectFolderName: projectFolderName, sessionID: conversation.sessionID)
        case .codex:
            command = RemoteCLICommandBuilder.loginShellCommand(
                "codex delete --force \(ShellQuoting.quoted(conversation.sessionID))"
            )
        case .kiro:
            let metadataFile = conversation.sourceFile.deletingPathExtension().appendingPathExtension("json")
            guard conversation.sourceFile.lastPathComponent == "\(conversation.sessionID).jsonl",
                  let metadata = KiroSessionMetadata(file: metadataFile),
                  metadata.sessionID == conversation.sessionID,
                  metadata.projectPath == conversation.projectPath,
                  conversation.projectPath.hasPrefix("/") else { throw ConversationDeletionError.invalidSource }
            command = RemoteKiroConversationDeletion.command(sessionID: conversation.sessionID, projectPath: conversation.projectPath)
        case .antigravity:
            let configurationDirectory = conversation.sourceFile.deletingLastPathComponent().deletingLastPathComponent()
            _ = try AntigravityDeletionFiles.validated(for: conversation, configurationDirectory: configurationDirectory)
            command = RemoteAntigravityConversationDeletion.command(sessionID: conversation.sessionID, projectPath: conversation.projectPath)
        case .pi:
            let names = try RemotePiConversationDeletion.hostFileNames(
                of: conversation,
                piMirrorDirectory: mirror.mirrorDirectory(host: host, provider: .pi)
            )
            command = RemotePiConversationDeletion.command(
                projectFolderName: names.projectFolderName,
                fileName: names.fileName,
                sessionID: conversation.sessionID
            )
        case .opencode:
            throw ConversationDeletionError.invalidSource
        }

        guard let result = runner.run(host, command, 60) else { throw RemoteConversationDeletionError.couldNotRun(host: host) }
        switch result.exitStatus {
        case 0:
            // The mirror would drop it on the next copy; dropping it now keeps the list right until then.
            try? FileManager.default.removeItem(at: conversation.sourceFile)
            if conversation.provider == .kiro {
                try? FileManager.default.removeItem(at: conversation.sourceFile.deletingPathExtension().appendingPathExtension("json"))
            }
            if conversation.provider == .antigravity {
                for file in AntigravityDeletionFiles.databaseFiles(conversation.sourceFile) { try? FileManager.default.removeItem(at: file) }
            }
        case RemoteHostCommandRunner.connectionFailureExitStatus:
            throw RemoteConversationDeletionError.sshFailed(host: host)
        case Self.missingTranscriptExitStatus where [.claude, .kiro, .antigravity, .pi].contains(conversation.provider):
            throw RemoteConversationDeletionError.missingOnHost(host: host)
        default:
            let details = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw RemoteConversationDeletionError.failed(
                host: host,
                details: details.isEmpty ? "exit status \(result.exitStatus)" : String(details.suffix(500))
            )
        }
    }

    /// A POSIX `sh` script, so it runs the same whatever the host's login shell is.
    static func claudeDeletionCommand(projectFolderName: String, sessionID: String) -> String {
        let script = """
            dir="$HOME/.claude/projects/"\(ShellQuoting.quoted(projectFolderName))
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
