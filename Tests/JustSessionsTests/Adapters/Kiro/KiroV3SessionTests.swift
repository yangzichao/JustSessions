import Foundation
import Testing

@testable import JustSessions

/// Kiro CLI's V3 sessions, `sessions/<workspace hash>/sess_<uuid>/`: listed beside V2's, read, and resumed under V3.
struct KiroV3SessionTests {
    private struct Home {
        let root: URL
        var sessionsRoot: URL { root.appendingPathComponent("sessions") }
        var classicDirectory: URL { sessionsRoot.appendingPathComponent("cli") }
        var v3: KiroV3SessionFixture { KiroV3SessionFixture(sessionsRoot: sessionsRoot) }
        var adapter: KiroAdapter { KiroAdapter(sessionsDirectory: classicDirectory, v3SessionsDirectory: sessionsRoot) }
        init() throws { root = try makeTemporaryDirectory() }
        func remove() { try? FileManager.default.removeItem(at: root) }
    }

    @Test func aV3SessionIsListedWithItsTitleFolderAndTimeBesideV2Sessions() throws {
        let home = try Home()
        defer { home.remove() }
        let written = try home.v3.writeSession(projectPath: "/Users/me/app", lastModifiedAt: "2099-01-01T00:00:00.000Z")
        let classicID = UUID().uuidString.lowercased()
        try KiroSessionFolderFixture(sessionsDirectory: home.classicDirectory).writeSession(
            id: classicID, projectPath: "/Users/me/app", messageLines: [KiroSessionFolderFixture.prompt("Old chat")]
        )

        let found = try home.adapter.discover()

        #expect(Set(found.map(\.sessionID)) == [written.sessionID, classicID])
        let v3 = try #require(found.first { $0.sessionID == written.sessionID })
        #expect(v3.provider == .kiro)
        #expect(v3.projectPath == "/Users/me/app")
        #expect(v3.suggestedTitle == "Fix the build")
        #expect(v3.sourceFile.resolvingSymlinksInPath().path == written.messagesFile.resolvingSymlinksInPath().path)
        #expect(v3.updatedAt == ISO8601TimestampParser.shared.date(from: "2099-01-01T00:00:00.000Z"))
    }

    @Test func anUntitledV3SessionTakesItsFirstPrompt() throws {
        let home = try Home()
        defer { home.remove() }
        try home.v3.writeSession(
            projectPath: "/Users/me/app", title: nil,
            events: [KiroV3SessionFixture.say("Hi"), KiroV3SessionFixture.user("  Add a health check  ")])

        #expect(try home.adapter.discover().map(\.suggestedTitle) == ["Add a health check"])
    }

    /// A subagent's session belongs to its parent, as Kiro's list shows it. Kiro writes `messages.jsonl` only once the
    /// session has a message, and names each folder for its session.
    @Test func subagentUnusedAndMalformedV3SessionsAreNotListed() throws {
        let home = try Home()
        defer { home.remove() }
        try home.v3.writeSession(projectPath: "/Users/me/app", createdReason: "subagent")
        try home.v3.writeSession(projectPath: "/Users/me/app", events: nil)
        try home.v3.writeSession(projectPath: "/Users/me/app", events: [])
        try home.v3.writeSession(projectPath: "relative/app")
        let renamed = try home.v3.writeSession(projectPath: "/Users/me/app")
        try FileManager.default.moveItem(
            at: renamed.folder,
            to: renamed.folder.deletingLastPathComponent().appendingPathComponent("sess_" + UUID().uuidString.lowercased()))
        try home.v3.writeSession(sessionID: "sess_not-a-uuid", projectPath: "/Users/me/app")

        let listed = try home.adapter.discover()
        #expect(listed.isEmpty, "listed: \(listed.map { ($0.sessionID, $0.projectPath, $0.suggestedTitle) })")
    }

    /// Forks you made, which Kiro lists as yours too.
    @Test func tangentAndRewindSessionsAreListed() throws {
        let home = try Home()
        defer { home.remove() }
        try home.v3.writeSession(projectPath: "/Users/me/app", createdReason: "tangent")
        try home.v3.writeSession(projectPath: "/Users/me/app", createdReason: "rewind")
        try home.v3.writeSession(projectPath: "/Users/me/app", createdReason: "human")

        #expect(try home.adapter.discover().count == 3)
    }

    /// The app's own adapter reads V3 beside the standard V2 folder; one given V2's folder alone reads V2's alone.
    @Test func v3IsReadBesideTheStandardFolderOnly() {
        let standard = KiroAdapter.standardSessionsDirectory()
        #expect(KiroAdapter().v3SessionsDirectory == standard.deletingLastPathComponent())
        #expect(KiroAdapter(sessionsDirectory: URL(fileURLWithPath: "/tmp/custom/sessions/cli")).v3SessionsDirectory == nil)
    }

    /// Kiro CLI 2.16.2 resumed a V3 session only so, interactively: with V2, its default, or the bare UUID, it started
    /// another conversation.
    @Test func aV3SessionResumesUnderV3WithItsSessIDAndAV2OneAsBefore() {
        let adapter = KiroAdapter(sessionsDirectory: URL(fileURLWithPath: "/unused"))
        let v3 = Conversation.fixture(provider: .kiro, sessionID: "sess_e43336d3-f851-4c02-b981-59c9421edb9f")
        let v2 = Conversation.fixture(provider: .kiro, sessionID: "a117957d-44d3-4375-b552-4373d8e5e74a")

        #expect(
            adapter.arguments(for: v3, action: .resume)
                == ["chat", "--agent-engine", "v3", "--resume-id", "sess_e43336d3-f851-4c02-b981-59c9421edb9f"])
        #expect(adapter.arguments(for: v2, action: .resume) == ["chat", "--resume-id", "a117957d-44d3-4375-b552-4373d8e5e74a"])
        #expect(adapter.arguments(for: v3, action: .new) == ["chat"])
        #expect(
            ConversationProvider.kiro.argumentsAfterCustomStartCommand(adapter.arguments(for: v3, action: .resume))
                == ["--agent-engine", "v3", "--resume-id", "sess_e43336d3-f851-4c02-b981-59c9421edb9f"])
    }

    @Test func aSessIDIsAValidKiroIDAndNamesItsTmuxSession() {
        let sessionID = "sess_e43336d3-f851-4c02-b981-59c9421edb9f"
        #expect(ConversationProvider.kiro.isValidSessionID(sessionID))
        #expect(!ConversationProvider.kiro.isValidSessionID("sess_not-a-uuid"))
        #expect(!ConversationProvider.claude.isValidSessionID(sessionID))
        let name = TmuxSessionName.forSession(provider: .kiro, sessionID: sessionID)
        #expect(TmuxSessionName.session(named: name)?.sessionID == sessionID)
    }

    /// Your prompt, its image, the reply, and the tool call; the context Kiro adds for the model, the reasoning, the result,
    /// the approval, usage, and the system prompt stay out.
    @Test func theReaderShowsPromptsRepliesAndToolCallsFromV3Events() throws {
        let home = try Home()
        defer { home.remove() }
        let events = KiroV3SessionFixture.sampleEvents.map { event in
            event["type"] as? String == "user" ? KiroV3SessionFixture.user("Look at this", images: 1) : event
        }
        let written = try home.v3.writeSession(projectPath: "/Users/me/app", events: events)

        let entries = try KiroTranscriptReader().read(written.messagesFile).entries.map(\.content)

        #expect(
            entries == [
                .userMessage("Look at this\n\n[Image]"),
                .toolCalls([ToolCallSummary.summary(toolName: "execute_bash", arguments: ["command": "swift build"])]),
                .assistantMessage("The build passes."),
            ])
    }

    /// The paged reader the reader, message search, and the conversation map share decodes each record as `read` does.
    @Test func eachV3RecordDecodesAsTheWholeFileReads() throws {
        let home = try Home()
        defer { home.remove() }
        let written = try home.v3.writeSession(projectPath: "/Users/me/app")
        let decoder = TranscriptRecordDecoder(provider: .kiro, maximumTextLength: 12_000)

        let paged = try JSONLinesReader.leadingLines(in: written.messagesFile, maximumByteCount: 1_000_000)
            .flatMap { decoder.entries(from: $0) }.map(\.content)

        #expect(paged == (try KiroTranscriptReader().read(written.messagesFile).entries.map(\.content)))
        #expect(paged.count == 3)
    }

    @Test func theFirstPromptOfAV3LogIsFound() throws {
        let lines = try KiroV3SessionFixture.lines([
            KiroV3SessionFixture.say("Hello"), KiroV3SessionFixture.user("   "),
            KiroV3SessionFixture.user("Ship it"),
        ])
        .split(separator: "\n").map { Data($0.utf8) }
        #expect(KiroFirstPrompt.find(amongLines: lines) == "Ship it")
    }

    @Test func aWorkspaceFolderIsNamedForItsPathsHash() {
        // As Kiro named the probe's folder on this Mac.
        #expect(KiroV3SessionFixture.workspaceHash(of: "/private/tmp/kiro-v3-probe") == "7b13d0ff170a04dc")
    }
}
