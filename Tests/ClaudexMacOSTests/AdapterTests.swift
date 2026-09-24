import Foundation
import Testing
@testable import ClaudexMacOS

struct AdapterTests {
    @Test func claudeDiscoversIndexedAndUnindexedSessions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appendingPathComponent("paper-revision")
        let sessions = root.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let indexedID = UUID().uuidString
        let unindexedID = UUID().uuidString
        try "{\"type\":\"user\",\"cwd\":\"\(project.path)\",\"message\":{\"content\":\"Draft intro\"},\"timestamp\":\"2026-09-20T10:00:00Z\"}\n{\"type\":\"custom-title\",\"customTitle\":\"Final paper title\",\"timestamp\":\"2026-09-22T10:00:00Z\"}\n"
            .write(to: sessions.appendingPathComponent("\(indexedID).jsonl"), atomically: true, encoding: .utf8)
        try "{\"type\":\"user\",\"cwd\":\"\(project.path)\",\"message\":{\"content\":\"Revise conclusion\"}}\n"
            .write(to: sessions.appendingPathComponent("\(unindexedID).jsonl"), atomically: true, encoding: .utf8)
        let index: [String: Any] = [
            "entries": [["sessionId": indexedID, "projectPath": project.path, "firstPrompt": "Indexed title"]],
            "originalPath": project.path,
        ]
        let indexData = try JSONSerialization.data(withJSONObject: index)
        try indexData.write(to: sessions.appendingPathComponent("sessions-index.json"))

        let adapter = ClaudeAdapter(configurationDirectory: root.appendingPathComponent(".claude"))
        let conversations = try adapter.discover()
        #expect(conversations.count == 2)
        #expect(conversations.first(where: { $0.sessionID == indexedID })?.suggestedTitle == "Final paper title")
        #expect(conversations.first(where: { $0.sessionID == indexedID })?.updatedAt == ConversationMetadata.date("2026-09-22T10:00:00Z"))
        #expect(conversations.first(where: { $0.sessionID == unindexedID })?.suggestedTitle == "Revise conclusion")
        #expect(adapter.arguments(for: conversations[0], action: .new).isEmpty)
        #expect(adapter.arguments(for: conversations[0], action: .branch).last == "--fork-session")
    }

    @Test func codexDiscoversTitleAndNativeCommands() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appendingPathComponent("backend-refactor")
        let sessions = root.appendingPathComponent(".codex/sessions/2026/09/23")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString
        let unindexedID = UUID().uuidString
        let rollout = sessions.appendingPathComponent("rollout-2026-09-23T10-00-00-\(sessionID).jsonl")
        try "{\"type\":\"session_meta\",\"payload\":{\"id\":\"\(sessionID)\",\"cwd\":\"\(project.path)\"}}\n"
            .write(to: rollout, atomically: true, encoding: .utf8)
        let indexLine = "{\"id\":\"\(sessionID)\",\"thread_name\":\"Fix API\",\"updated_at\":\"2026-09-23T10:00:00Z\"}\n"
        try indexLine.write(to: root.appendingPathComponent(".codex/session_index.jsonl"), atomically: true, encoding: .utf8)
        let unindexedRollout = sessions.appendingPathComponent("rollout-2026-09-23T11-00-00-\(unindexedID).jsonl")
        try "{\"type\":\"session_meta\",\"payload\":{\"id\":\"\(unindexedID)\",\"cwd\":\"\(project.path)\"}}\n{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":\"Refactor backend\"}]}}\n"
            .write(to: unindexedRollout, atomically: true, encoding: .utf8)

        let adapter = CodexAdapter(codexDirectory: root.appendingPathComponent(".codex"))
        let conversations = try adapter.discover()
        #expect(conversations.count == 2)
        #expect(conversations.first(where: { $0.sessionID == sessionID })?.suggestedTitle == "Fix API")
        #expect(conversations.first(where: { $0.sessionID == unindexedID })?.suggestedTitle == "Refactor backend")
        #expect(adapter.arguments(for: conversations[0], action: .new).isEmpty)
        #expect(adapter.arguments(for: conversations[0], action: .resume) == ["resume", conversations[0].sessionID])
        #expect(adapter.arguments(for: conversations[0], action: .branch) == ["fork", conversations[0].sessionID])
    }

    @Test func nativeCommandUsesExecutableAndProjectDirectoryWithoutShellQuoting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let binaryDirectory = root.appendingPathComponent("bin with spaces")
        let projectDirectory = root.appendingPathComponent("it's a project")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let executable = binaryDirectory.appendingPathComponent("claude")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let conversation = Conversation(
            provider: .claude,
            sessionID: UUID().uuidString,
            projectPath: projectDirectory.path,
            suggestedTitle: "Example",
            updatedAt: .now,
            sourceFile: root.appendingPathComponent("session.jsonl")
        )
        let resolver = NativeCLICommandResolver(
            searchDirectories: [binaryDirectory.path],
            inheritedEnvironment: ["HOME": root.path, "PATH": binaryDirectory.path]
        )

        let command = try resolver.resolve(conversation: conversation, action: .branch, adapter: ClaudeAdapter())
        #expect(command.executablePath == executable.path)
        #expect(command.workingDirectory == projectDirectory.path)
        #expect(command.arguments == ["--resume", conversation.sessionID, "--fork-session"])
        #expect(command.environment.contains("TERM=xterm-256color"))
    }

    @Test func newSessionStartsBareNativeCLIInSelectedProject() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let binaryDirectory = root.appendingPathComponent("bin")
        let projectDirectory = root.appendingPathComponent("new project")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        for executableName in ["claude", "codex"] {
            let executable = binaryDirectory.appendingPathComponent(executableName)
            try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        }
        let resolver = NativeCLICommandResolver(searchDirectories: [binaryDirectory.path])

        for provider in ConversationProvider.allCases {
            let command = try resolver.resolveNewSession(provider: provider, projectPath: projectDirectory.path)
            #expect(command.arguments.isEmpty)
            #expect(command.workingDirectory == projectDirectory.path)
            #expect(command.executablePath == binaryDirectory.appendingPathComponent(provider == .claude ? "claude" : "codex").path)
        }
    }
}
