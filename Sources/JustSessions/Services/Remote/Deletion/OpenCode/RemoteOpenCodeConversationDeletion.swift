import Foundation
import SQLite3

enum RemoteOpenCodeConversationDeletion {
    /// Deletes with OpenCode's own CLI, from the database the mirror was copied from; it also deletes the session's
    /// subagent sessions. OpenCode's error for an unknown session means it is already gone.
    static func command(sessionID: String, host: String) -> String {
        let script = OpenCodeRemoteDatabaseLocation.shellAssignment + """

            id=\(ShellQuoting.quoted(sessionID))
            [ -f "$db" ] || exit \(RemoteConversationDeletion.missingTranscriptExitStatus)
            cd "${db%/*}" || exit 1
            output=$(OPENCODE_DB="$db" opencode session delete "$id" 2>&1)
            opencode_exit_status=$?
            if [ "$opencode_exit_status" -ne 0 ]; then
              case "$output" in
                *"Session not found"*) exit \(RemoteConversationDeletion.missingTranscriptExitStatus) ;;
              esac
              printf '%s\\n' "$output" >&2
              echo "OpenCode exited with code $opencode_exit_status." >&2
              exit 1
            fi
            """
        return RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))", on: host)
    }

    /// The host's mirror database, when `conversation` is one of its sessions.
    static func validatedMirrorDatabase(for conversation: Conversation, mirror: RemoteSessionMirror, host: String) throws -> URL {
        let databaseFile = mirror.mirrorDirectory(host: host, provider: .opencode).appendingPathComponent("opencode.db")
        guard conversation.sourceFile.standardizedFileURL.path == databaseFile.standardizedFileURL.path,
              try OpenCodeDatabase.containsTopLevelSession(conversation.sessionID, projectPath: conversation.projectPath, in: databaseFile)
        else { throw ConversationDeletionError.invalidSource }
        return databaseFile
    }

    /// The mirror holds every session of the host, so only the deleted session's rows leave it.
    static func removeMirrorRows(of sessionID: String, from databaseFile: URL) {
        guard let database = try? OpenCodeDatabase.open(databaseFile, writable: true) else { return }
        defer { sqlite3_close(database) }
        guard (try? OpenCodeDatabase.execute("BEGIN IMMEDIATE", in: database)) != nil else { return }
        for query in ["DELETE FROM part WHERE session_id = ?", "DELETE FROM message WHERE session_id = ?", "DELETE FROM session WHERE id = ?"] {
            guard let statement = try? OpenCodeDatabase.prepare(query, in: database) else {
                try? OpenCodeDatabase.execute("ROLLBACK", in: database)
                return
            }
            OpenCodeDatabase.bind(sessionID, at: 1, in: statement)
            let result = sqlite3_step(statement)
            sqlite3_finalize(statement)
            guard result == SQLITE_DONE else {
                try? OpenCodeDatabase.execute("ROLLBACK", in: database)
                return
            }
        }
        try? OpenCodeDatabase.execute("COMMIT", in: database)
    }
}
