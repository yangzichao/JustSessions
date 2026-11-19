import Foundation
import Testing

@testable import JustSessions

struct KiroAdapterTests {
    @Test func listsUsedSessionsWithTheirTitleOrFirstPrompt() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = KiroSessionFolderFixture(sessionsDirectory: root)
        let titledID = UUID().uuidString.lowercased()
        let untitledID = UUID().uuidString.lowercased()
        try fixture.writeSession(
            id: titledID, projectPath: "/Users/me/app", title: "Login fix",
            messageLines: [
                KiroSessionFolderFixture.prompt("Fix the login bug"), KiroSessionFolderFixture.reply,
            ])
        try fixture.writeSession(
            id: untitledID, projectPath: "/Users/me/api", updatedAt: "2099-01-01T00:00:00Z",
            messageLines: [
                KiroSessionFolderFixture.reply, KiroSessionFolderFixture.prompt("Add a health check"),
            ])

        let found = try KiroAdapter(sessionsDirectory: root).discover()

        #expect(found.count == 2)
        let titled = try #require(found.first { $0.sessionID == titledID })
        #expect(titled.provider == .kiro)
        #expect(titled.projectPath == "/Users/me/app")
        #expect(titled.suggestedTitle == "Login fix")
        #expect(titled.sourceFile.lastPathComponent == "\(titledID).jsonl")
        let untitled = try #require(found.first { $0.sessionID == untitledID })
        #expect(untitled.suggestedTitle == "Add a health check")
        #expect(untitled.updatedAt == ISO8601TimestampParser.shared.date(from: "2099-01-01T00:00:00Z"))
    }

    /// Kiro CLI 2.16's terminal UI runs the chat as an ACP agent and marks every session it starts `subagent`, the tab's own
    /// main session included; before this, none of its sessions was listed and a new Kiro tab never linked.
    @Test func listsAMainSessionMarkedSubagentThatNamesNoParent() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = UUID().uuidString.lowercased()
        try KiroSessionFolderFixture(sessionsDirectory: root).writeSession(
            id: sessionID, projectPath: "/Users/me/app", title: "Fix the build", createdReason: "subagent",
            messageLines: [KiroSessionFolderFixture.prompt("Fix the build"), KiroSessionFolderFixture.reply]
        )

        let found = try KiroAdapter(sessionsDirectory: root).discover()

        #expect(found.map(\.sessionID) == [sessionID])
        #expect(found.first?.suggestedTitle == "Fix the build")
    }

    @Test func skipsSubagentUnusedAndMalformedSessions() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = KiroSessionFolderFixture(sessionsDirectory: root)
        let prompt = [KiroSessionFolderFixture.prompt("Hi")]
        try fixture.writeSession(
            id: UUID().uuidString, projectPath: "/Users/me/app", createdReason: "subagent",
            parentSessionID: UUID().uuidString.lowercased(), messageLines: prompt)
        try fixture.writeSession(
            id: UUID().uuidString, projectPath: "/Users/me/app", parentSessionID: UUID().uuidString.lowercased(),
            messageLines: prompt)
        try fixture.writeSession(id: UUID().uuidString, projectPath: "/Users/me/app", createdReason: "subagent", messageLines: [])
        try fixture.writeSession(id: UUID().uuidString, projectPath: "/Users/me/app", messageLines: [])
        try fixture.writeSession(id: "not-a-uuid", projectPath: "/Users/me/app", messageLines: prompt)
        try fixture.writeSession(id: UUID().uuidString, projectPath: "relative/app", messageLines: prompt)
        let orphanID = UUID().uuidString
        try fixture.writeSession(id: orphanID, projectPath: "/Users/me/app", messageLines: prompt)
        try FileManager.default.removeItem(at: root.appendingPathComponent("\(orphanID).jsonl"))

        #expect(try KiroAdapter(sessionsDirectory: root).discover().isEmpty)
    }

    @Test func sessionsFolderIsInKirosHome() {
        #expect(
            KiroAdapter.standardSessionsDirectory(environment: [:], homeDirectory: "/Users/me").path
                == "/Users/me/.kiro/sessions/cli")
        #expect(
            KiroAdapter.standardSessionsDirectory(environment: ["KIRO_HOME": "/opt/kiro"], homeDirectory: "/Users/me").path
                == "/opt/kiro/sessions/cli")
    }

    @Test func aMetadataFileNamedForAnotherSessionIsNotListed() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = UUID().uuidString.lowercased()
        let otherSessionID = UUID().uuidString.lowercased()
        try KiroSessionFolderFixture(sessionsDirectory: root).writeSession(
            id: sessionID,
            projectPath: "/Users/me/app",
            messageLines: [KiroSessionFolderFixture.prompt("Keep me")]
        )
        for fileExtension in ["json", "jsonl"] {
            try FileManager.default.moveItem(
                at: root.appendingPathComponent("\(sessionID).\(fileExtension)"),
                to: root.appendingPathComponent("\(otherSessionID).\(fileExtension)")
            )
        }

        #expect(try KiroAdapter(sessionsDirectory: root).discover().isEmpty)
    }

    @Test func firstPromptSkipsOtherLinesAndBlankText() {
        let blankPrompt = #"{"version":"v1","kind":"Prompt","data":{"content":[{"kind":"image","data":"…"},{"kind":"text","data":"  "}]}}"#
        let lines = jsonLines([KiroSessionFolderFixture.reply, blankPrompt, KiroSessionFolderFixture.prompt("Real prompt")])
        #expect(KiroFirstPrompt.find(amongLines: lines) == "Real prompt")
        #expect(KiroFirstPrompt.find(amongLines: jsonLines([KiroSessionFolderFixture.reply])) == nil)
    }
}
