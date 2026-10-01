import Foundation
@testable import JustSessions

/// A custom Kiro home and project, deleted by a stand-in CLI without touching the user's history.
struct KiroHomeFixture {
    let root: URL
    let kiroDirectory: URL
    let sessionsDirectory: URL
    let projectDirectory: URL
    let conversation: Conversation

    init() throws {
        root = try makeTemporaryDirectory()
        kiroDirectory = root.appendingPathComponent("custom kiro home; $dollar")
        sessionsDirectory = kiroDirectory.appendingPathComponent("sessions/cli")
        projectDirectory = root.appendingPathComponent("project with spaces")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString.lowercased()
        try KiroSessionFolderFixture(sessionsDirectory: sessionsDirectory).writeSession(
            id: sessionID,
            projectPath: projectDirectory.path,
            title: "Delete me",
            messageLines: [KiroSessionFolderFixture.prompt("Fix the login bug")]
        )
        conversation = .fixture(
            provider: .kiro,
            sessionID: sessionID,
            projectPath: projectDirectory.path,
            sourceFile: sessionsDirectory.appendingPathComponent("\(sessionID).jsonl")
        )
    }

    var metadataFile: URL {
        conversation.sourceFile.deletingPathExtension().appendingPathExtension("json")
    }

    static let successfulDeletionScript = """
        #!/bin/sh
        [ "$1" = chat ] && [ "$2" = --delete-session ] && [ "$#" -eq 3 ] || exit 9
        /bin/rm -f "$KIRO_HOME/sessions/cli/$3.jsonl" "$KIRO_HOME/sessions/cli/$3.json"
        """

    func executable(running script: String = Self.successfulDeletionScript) throws -> URL {
        try writeExecutableScript(script, to: root.appendingPathComponent("kiro-cli"))
    }

    func delete(_ conversation: Conversation? = nil, runningScript script: String, timeout: TimeInterval = 60) throws {
        try KiroConversationDeletion(
            sessionsDirectory: sessionsDirectory,
            executableURL: executable(running: script),
            timeout: timeout
        ).delete(conversation ?? self.conversation)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
