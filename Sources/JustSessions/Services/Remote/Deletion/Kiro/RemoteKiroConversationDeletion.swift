import Foundation

/// As on this Mac (`KiroConversationDeletion`): a session a running Kiro CLI holds isn't handed to Kiro, and the prompts
/// Kiro leaves in `sessions/cli/<id>.history`, with a V2 session's lock its CLI left, go once it has deleted the rest.
enum RemoteKiroConversationDeletion {
    static let refusingWhileLocked = """
        lock_is_held() {
          [ -f "$lock" ] || return 1
          pid=$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p' "$lock" | head -n 1)
          [ -n "$pid" ] && [ "$pid" -gt 1 ] && kill -0 "$pid" 2>/dev/null
        }
        if lock_is_held; then sleep 1; fi
        if lock_is_held; then sleep 1; fi
        if lock_is_held; then
          echo \(ShellQuoting.quoted(KiroConversationDeletionError.stillRunning.localizedDescription)) >&2
          exit 1
        fi
        """

    static func removingLeftovers(_ fileExtensions: [String]) -> String {
        fileExtensions.map { fileExtension in
            """
            leftover="$dir/$id.\(fileExtension)"
            if [ -f "$leftover" ] && [ ! -L "$leftover" ]; then rm -f "$leftover"; fi
            """
        }.joined(separator: "\n")
    }

    static func command(sessionID: String, projectPath: String, sessionsFolder: String, host: String) -> String {
        let script = """
            dir=\(sessionsFolder)
            id=\(ShellQuoting.quoted(sessionID))
            [ -f "$dir/$id.jsonl" ] && [ -f "$dir/$id.json" ] || exit \(RemoteConversationDeletion.missingTranscriptExitStatus)
            lock="$dir/$id.lock"
            \(refusingWhileLocked)
            if [ -d \(ShellQuoting.quoted(projectPath)) ]; then
              cd \(ShellQuoting.quoted(projectPath)) || exit 1
            fi
            KIRO_HOME="${dir%/sessions/cli}" kiro-cli chat --delete-session "$id"
            kiro_exit_status=$?
            if [ "$kiro_exit_status" -ne 0 ]; then
              echo "Kiro CLI exited with code $kiro_exit_status." >&2
              exit 1
            fi
            if [ -e "$dir/$id.jsonl" ] || [ -e "$dir/$id.json" ]; then
              echo 'Kiro CLI reported success, but the session files are still present.' >&2
              exit 1
            fi
            \(removingLeftovers(["history", "lock"]))
            """
        return RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))", on: host)
    }

    /// A V3 session's folder, `<workspace folder>/<sess_ id>` in the `sessions` folder that holds `sessions/cli`
    /// (`sessionsFolder`); see `KiroV3Session`. Kiro deletes the whole folder.
    static func v3Command(
        sessionID: String, workspaceFolderName: String, projectPath: String, sessionsFolder: String,
        host: String
    ) -> String {
        let script = """
            dir=\(sessionsFolder)
            id=\(ShellQuoting.quoted(sessionID))
            session="${dir%/cli}"/\(ShellQuoting.quoted(workspaceFolderName))/"$id"
            [ -f "$session/\(KiroV3Session.metadataFileName)" ] && [ -f "$session/\(KiroV3Session.messagesFileName)" ] \\
              || exit \(RemoteConversationDeletion.missingTranscriptExitStatus)
            lock="$session/.lock"
            \(refusingWhileLocked)
            if [ -d \(ShellQuoting.quoted(projectPath)) ]; then
              cd \(ShellQuoting.quoted(projectPath)) || exit 1
            fi
            KIRO_HOME="${dir%/sessions/cli}" kiro-cli chat --delete-session "$id"
            kiro_exit_status=$?
            if [ "$kiro_exit_status" -ne 0 ]; then
              echo "Kiro CLI exited with code $kiro_exit_status." >&2
              exit 1
            fi
            if [ -e "$session" ]; then
              echo 'Kiro CLI reported success, but the session folder is still present.' >&2
              exit 1
            fi
            \(removingLeftovers(["history"]))
            """
        return RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))", on: host)
    }
}
