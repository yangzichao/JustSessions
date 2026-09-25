import Foundation

enum RemoteConversationDeletionError: LocalizedError {
    case couldNotRun(host: String)
    case sshFailed(host: String)
    case missingOnHost(host: String)
    case failed(host: String, details: String)

    var errorDescription: String? {
        switch self {
        case .couldNotRun(let host): "Deleting the session on \(host) did not start or did not finish within a minute."
        case .sshFailed(let host): "Could not connect to \(host) to delete the session."
        case .missingOnHost(let host): "The session file is no longer on \(host). Refresh the conversation list."
        case .failed(let host, let details): "Could not delete the session on \(host): \(details)"
        }
    }
}

/// Deletes a session on its remote host over SSH. Remote hosts have no Trash, so this is permanent.
/// Claude Code sessions lose their transcript, companion folder, and index entry; Codex deletes its own.
struct RemoteConversationDeletion {
    let runner: RemoteHostCommandRunner

    init(runner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        self.runner = runner
    }

    /// Exit status of the Claude Code script when the transcript is already gone.
    static let missingTranscriptExitStatus: Int32 = 3

    func delete(_ conversation: Conversation) throws {
        guard let host = conversation.remoteHost,
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
        case .antigravity:
            throw ConversationDeletionError.invalidSource
        }

        guard let result = runner.run(host, command, 60) else { throw RemoteConversationDeletionError.couldNotRun(host: host) }
        switch result.exitStatus {
        case 0:
            // The mirror would drop it on the next copy; dropping it now keeps the list right until then.
            try? FileManager.default.removeItem(at: conversation.sourceFile)
        case RemoteHostCommandRunner.connectionFailureExitStatus:
            throw RemoteConversationDeletionError.sshFailed(host: host)
        case Self.missingTranscriptExitStatus where conversation.provider == .claude:
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
