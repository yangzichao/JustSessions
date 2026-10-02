import Foundation
import Testing
@testable import JustSessions

struct CodexAdapterTests {
    @Test func discoversTitleAndNativeCommands() throws {
        let root = try makeTemporaryDirectory()
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

    @Test func onlyRolloutsThatStartWithAValidSessionMetaLineAreListed() throws {
        let home = try CodexRolloutFolderFixture()
        defer { home.remove() }
        let listed = UUID().uuidString
        try home.writeRollout(sessionID: listed)
        try home.writeRollout(sessionID: "not-a-uuid")
        try home.writeRollout(named: "rollout-2026-09-24T10-00-00-\(UUID().uuidString).jsonl", lines: [
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"No meta line first"}]}}"#,
        ])
        try home.writeRollout(named: "rollout-2026-09-24T10-00-00-\(UUID().uuidString).jsonl", lines: [
            #"{"type":"session_meta","payload":{"id":"\#(UUID().uuidString)"}}"#,
        ])
        try home.writeRollout(named: "session-\(UUID().uuidString).jsonl", lines: [
            #"{"type":"session_meta","payload":{"id":"\#(UUID().uuidString)","cwd":"/Users/me/app"}}"#,
        ])

        #expect(try home.discover().map(\.sessionID) == [listed])
    }

    @Test func updatedAtIsTheLaterOfTheIndexTimeAndTheFileDate() throws {
        let home = try CodexRolloutFolderFixture()
        defer { home.remove() }
        let indexIsLater = UUID().uuidString
        let fileIsLater = UUID().uuidString
        let fileDate = Date(timeIntervalSince1970: 1_790_000_000)
        for sessionID in [indexIsLater, fileIsLater] {
            let rollout = try home.writeRollout(sessionID: sessionID)
            try FileManager.default.setAttributes([.modificationDate: fileDate], ofItemAtPath: rollout.path)
        }
        try home.writeIndex(lines: [
            #"{"id":"\#(indexIsLater)","thread_name":"Later","updated_at":"2026-09-24T10:00:00Z"}"#,
            #"{"id":"\#(fileIsLater)","thread_name":"Earlier","updated_at":"2026-09-01T10:00:00Z"}"#,
        ])

        let updatedAt = Dictionary(uniqueKeysWithValues: try home.discover().map { ($0.sessionID, $0.updatedAt) })
        #expect(updatedAt[indexIsLater] == ConversationMetadata.date("2026-09-24T10:00:00Z"))
        #expect(updatedAt[fileIsLater] == fileDate)
    }

    @Test func aRolloutCodexWroteMoreToSinceTheLastScanIsReadAgain() throws {
        let home = try CodexRolloutFolderFixture()
        defer { home.remove() }
        let sessionID = UUID().uuidString
        try home.writeRollout(sessionID: sessionID)
        #expect(try home.discover().first?.suggestedTitle == ConversationMetadata.untitledConversationTitle)

        try home.writeRollout(sessionID: sessionID, laterLines: [
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Refactor backend"}]}}"#,
        ])

        #expect(try home.discover().first?.suggestedTitle == "Refactor backend")
    }
}
