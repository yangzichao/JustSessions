import Foundation
import Testing
@testable import ClaudexMacOS

struct ConversationDeletionTests {
    @Test func claudeMovesOnlySelectedSessionAndCompanionToTrash() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let configurationDirectory = root.appendingPathComponent(".claude")
        let projectDirectory = configurationDirectory.appendingPathComponent("projects/project")
        let trashDirectory = root.appendingPathComponent("test-trash")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        let deletedID = UUID().uuidString
        let retainedID = UUID().uuidString
        let deletedFile = projectDirectory.appendingPathComponent("\(deletedID).jsonl")
        let retainedFile = projectDirectory.appendingPathComponent("\(retainedID).jsonl")
        let companionDirectory = projectDirectory.appendingPathComponent(deletedID)
        try "conversation".write(to: deletedFile, atomically: true, encoding: .utf8)
        try "other conversation".write(to: retainedFile, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: companionDirectory, withIntermediateDirectories: true)
        try "artifact".write(to: companionDirectory.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        let index: [String: Any] = [
            "originalPath": "/example",
            "entries": [["sessionId": deletedID], ["sessionId": retainedID]],
        ]
        let indexFile = projectDirectory.appendingPathComponent("sessions-index.json")
        try JSONSerialization.data(withJSONObject: index).write(to: indexFile)
        let conversation = Conversation(
            provider: .claude,
            sessionID: deletedID,
            projectPath: "/example",
            suggestedTitle: "Delete me",
            updatedAt: .now,
            sourceFile: deletedFile
        )
        let deletion = ClaudeConversationDeletion(configurationDirectory: configurationDirectory) { source in
            try FileManager.default.moveItem(
                at: source,
                to: trashDirectory.appendingPathComponent(source.lastPathComponent)
            )
        }

        try deletion.delete(conversation)

        #expect(!FileManager.default.fileExists(atPath: deletedFile.path))
        #expect(FileManager.default.fileExists(atPath: retainedFile.path))
        #expect(FileManager.default.fileExists(atPath: trashDirectory.appendingPathComponent("\(deletedID).jsonl").path))
        #expect(FileManager.default.fileExists(atPath: trashDirectory.appendingPathComponent("\(deletedID)/notes.txt").path))
        let updatedIndex = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: indexFile)) as? [String: Any])
        let entries = try #require(updatedIndex["entries"] as? [[String: Any]])
        #expect(entries.map { $0["sessionId"] as? String } == [retainedID])
    }

    @Test func codexUsesNativeDeleteWithExactSessionID() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let codexDirectory = root.appendingPathComponent(".codex")
        let sessionDirectory = codexDirectory.appendingPathComponent("sessions/2026/09/23")
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString
        let sourceFile = sessionDirectory.appendingPathComponent("rollout-2026-09-23T10-00-00-\(sessionID).jsonl")
        try "{\"type\":\"session_meta\",\"payload\":{\"id\":\"\(sessionID)\",\"cwd\":\"/example\"}}\n"
            .write(to: sourceFile, atomically: true, encoding: .utf8)
        let argsFile = root.appendingPathComponent("args.txt")
        let fakeExecutable = root.appendingPathComponent("codex")
        let script = "#!/bin/sh\nprintf '%s\\n' \"$@\" > '\(argsFile.path)'\nfind '\(sessionDirectory.path)' -name '*.jsonl' -delete\n"
        try script.write(to: fakeExecutable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeExecutable.path)
        let conversation = Conversation(
            provider: .codex,
            sessionID: sessionID,
            projectPath: "/example",
            suggestedTitle: "Delete me",
            updatedAt: .now,
            sourceFile: sourceFile
        )

        try CodexConversationDeletion(codexDirectory: codexDirectory, executableURL: fakeExecutable)
            .delete(conversation)

        #expect(try String(contentsOf: argsFile, encoding: .utf8).split(separator: "\n").map(String.init) == [
            "delete", "--force", sessionID,
        ])
        #expect(!FileManager.default.fileExists(atPath: sourceFile.path))
    }

    @Test func claudeRejectsSessionOutsideHistoryFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString
        let unrelatedFile = root.appendingPathComponent("\(sessionID).jsonl")
        try "keep this".write(to: unrelatedFile, atomically: true, encoding: .utf8)
        let conversation = Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: root.path,
            suggestedTitle: "Unrelated",
            updatedAt: .now,
            sourceFile: unrelatedFile
        )

        #expect(throws: ConversationDeletionError.self) {
            try ClaudeConversationDeletion(configurationDirectory: root.appendingPathComponent(".claude"))
                .delete(conversation)
        }
        #expect(FileManager.default.fileExists(atPath: unrelatedFile.path))
    }
}
