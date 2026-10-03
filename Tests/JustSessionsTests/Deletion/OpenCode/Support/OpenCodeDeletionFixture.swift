import Foundation
@testable import JustSessions

/// An OpenCode data folder with one session to delete and one to keep, and a stand-in `opencode` CLI.
struct OpenCodeDeletionFixture {
    static let selectedSessionID = "ses_selected00001"
    static let retainedSessionID = "ses_retained00001"
    static let subagentSessionID = "ses_subagent00001"

    /// Deletes a session and its subagent sessions from `OPENCODE_DB` as `opencode session delete` does, and
    /// reports an unknown session in color as OpenCode does.
    static let deletingScript = """
        #!/bin/sh
        [ "$1" = session ] && [ "$2" = delete ] || exit 2
        sessions="SELECT id FROM session WHERE id = '$3' OR parent_id = '$3'"
        if [ "$(/usr/bin/sqlite3 "$OPENCODE_DB" "SELECT count(*) FROM session WHERE id = '$3'")" = 0 ]; then
          printf '\\033[91m\\033[1mError: \\033[0mSession not found: %s\\n' "$3" >&2
          exit 1
        fi
        /usr/bin/sqlite3 "$OPENCODE_DB" "DELETE FROM part WHERE session_id IN ($sessions); DELETE FROM message WHERE session_id IN ($sessions); DELETE FROM session WHERE id IN ($sessions);"
        echo "Session $3 deleted"
        """

    let root: URL
    let projectDirectory: URL
    let database: OpenCodeDatabaseFixture
    var reportFile: URL { root.appendingPathComponent("report.txt") }

    init() throws {
        root = try makeTemporaryDirectory()
        projectDirectory = root.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let dataDirectory = root.appendingPathComponent("data/opencode")
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        database = try OpenCodeDatabaseFixture(file: dataDirectory.appendingPathComponent("opencode.db"))
        try database.addSession(Self.selectedSessionID, directory: projectDirectory.path, title: "Delete me")
        try database.addSession(Self.subagentSessionID, directory: projectDirectory.path, parentID: Self.selectedSessionID)
        try database.addSession(Self.retainedSessionID, directory: projectDirectory.path, title: "Keep me")
        try database.addUserPrompt("msg_selected", session: Self.selectedSessionID, createdAt: 1, text: "Delete me")
        try database.addUserPrompt("msg_subagent", session: Self.subagentSessionID, createdAt: 1, text: "Subtask")
        try database.addUserPrompt("msg_retained", session: Self.retainedSessionID, createdAt: 1, text: "Keep me")
    }

    /// The stand-in CLI; it first records its arguments, `OPENCODE_DB`, and working directory.
    func executable(running script: String = deletingScript) throws -> URL {
        let reporting = script.replacingOccurrences(
            of: "#!/bin/sh\n",
            with: "#!/bin/sh\nprintf '%s\\n' \"$@\" \"$OPENCODE_DB\" \"$PWD\" > \(ShellQuoting.quoted(reportFile.path))\n"
        )
        return try writeExecutableScript(reporting, to: root.appendingPathComponent("opencode"))
    }

    func adapter(running script: String = deletingScript) throws -> OpenCodeAdapter {
        OpenCodeAdapter(databaseFile: database.file, deletionExecutableURL: try executable(running: script))
    }

    func selectedConversation() throws -> Conversation {
        guard let conversation = try OpenCodeAdapter(databaseFile: database.file).discover()
            .first(where: { $0.sessionID == Self.selectedSessionID })
        else { throw NSError(domain: "OpenCodeDeletionFixture", code: 1) }
        return conversation
    }

    func report() throws -> [String] {
        try String(contentsOf: reportFile, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
