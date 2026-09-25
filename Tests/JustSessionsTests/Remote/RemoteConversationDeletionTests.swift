import Foundation
import Testing
@testable import JustSessions

struct RemoteConversationDeletionTests {
    /// Runs the deletion script with a temporary folder as the remote home, the way `ssh host <command>` would.
    @Test func claudeDeletionRemovesTranscriptCompanionFolderAndIndexEntry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let projectFolder = root.appendingPathComponent("home/.claude/projects/-home-me-bob's paper")
        let sessionID = UUID().uuidString.lowercased()
        let keptID = UUID().uuidString.lowercased()
        try FileManager.default.createDirectory(at: projectFolder.appendingPathComponent("\(sessionID)/subagents"), withIntermediateDirectories: true)
        try "{}".write(to: projectFolder.appendingPathComponent("\(sessionID).jsonl"), atomically: true, encoding: .utf8)
        try "{}".write(to: projectFolder.appendingPathComponent("\(keptID).jsonl"), atomically: true, encoding: .utf8)
        let index: [String: Any] = ["entries": [["sessionId": sessionID], ["sessionId": keptID]], "originalPath": "/home/me"]
        try JSONSerialization.data(withJSONObject: index).write(to: projectFolder.appendingPathComponent("sessions-index.json"))

        let mirrorFile = root.appendingPathComponent("mirror/projects/-home-me-bob's paper/\(sessionID).jsonl")
        try FileManager.default.createDirectory(at: mirrorFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{}".write(to: mirrorFile, atomically: true, encoding: .utf8)
        let deletion = RemoteConversationDeletion(runOnHost: localShell(home: root.appendingPathComponent("home")))
        let conversation = remoteConversation(.claude, sessionID: sessionID, sourceFile: mirrorFile)

        try deletion.delete(conversation)

        let fileManager = FileManager.default
        #expect(!fileManager.fileExists(atPath: projectFolder.appendingPathComponent("\(sessionID).jsonl").path))
        #expect(!fileManager.fileExists(atPath: projectFolder.appendingPathComponent(sessionID).path))
        #expect(fileManager.fileExists(atPath: projectFolder.appendingPathComponent("\(keptID).jsonl").path))
        #expect(!fileManager.fileExists(atPath: mirrorFile.path))
        let updatedIndex = try JSONSerialization.jsonObject(
            with: Data(contentsOf: projectFolder.appendingPathComponent("sessions-index.json"))
        ) as? [String: Any]
        let remainingIDs = (updatedIndex?["entries"] as? [[String: Any]])?.compactMap { $0["sessionId"] as? String }
        #expect(remainingIDs == [keptID])
        #expect(updatedIndex?["originalPath"] as? String == "/home/me")

        #expect(throws: RemoteConversationDeletionError.self) { try deletion.delete(conversation) }
    }

    @Test func codexDeletionRunsTheNativeCommandThroughTheLoginShell() throws {
        let sessionID = UUID().uuidString
        var receivedHost: String?
        var receivedCommand: String?
        let deletion = RemoteConversationDeletion { host, command in
            receivedHost = host
            receivedCommand = command
            return (0, "")
        }

        try deletion.delete(remoteConversation(.codex, sessionID: sessionID, sourceFile: URL(fileURLWithPath: "/tmp/rollout-\(sessionID).jsonl")))

        #expect(receivedHost == "devbox")
        #expect(receivedCommand == RemoteCLICommandBuilder.loginShellCommand("codex delete --force '\(sessionID)'"))
    }

    @Test func unreachableHostIsReportedAsAConnectionProblem() {
        let deletion = RemoteConversationDeletion { _, _ in (255, "ssh: connect to host devbox port 22: Connection refused") }
        let conversation = remoteConversation(.codex, sessionID: UUID().uuidString, sourceFile: URL(fileURLWithPath: "/tmp/x.jsonl"))
        #expect(throws: RemoteConversationDeletionError.self) { try deletion.delete(conversation) }
    }

    private func localShell(home: URL) -> (String, String) -> (exitStatus: Int32, output: String)? {
        { _, command in
            BoundedProcessRunner.result(
                ofExecutable: "/bin/sh",
                arguments: ["-c", command],
                environment: ["HOME": home.path, "PATH": "/usr/bin:/bin"],
                includesStandardError: true,
                timeout: 20
            )
        }
    }

    private func remoteConversation(_ provider: ConversationProvider, sessionID: String, sourceFile: URL) -> Conversation {
        Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: "/home/me/paper",
            suggestedTitle: "Session",
            updatedAt: .now,
            sourceFile: sourceFile,
            remoteHost: "devbox"
        )
    }
}
