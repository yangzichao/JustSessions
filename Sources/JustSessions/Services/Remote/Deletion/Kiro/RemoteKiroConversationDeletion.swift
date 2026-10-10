import Foundation

enum RemoteKiroConversationDeletion {
    /// Targets the Kiro home the mirror copied from, whose `sessions/cli` is `sessionsFolder`, in `sh`; see
    /// `RemoteToolFolders.shellPath(for:)`.
    static func command(sessionID: String, projectPath: String, sessionsFolder: String, host: String) -> String {
        let script = """
            dir=\(sessionsFolder)
            id=\(ShellQuoting.quoted(sessionID))
            [ -f "$dir/$id.jsonl" ] && [ -f "$dir/$id.json" ] || exit \(RemoteConversationDeletion.missingTranscriptExitStatus)
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
            """
        return RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))", on: host)
    }
}
