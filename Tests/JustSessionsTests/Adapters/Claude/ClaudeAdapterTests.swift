import Foundation
import Testing

@testable import JustSessions

struct ClaudeAdapterTests {
    @Test func discoversIndexedAndUnindexedSessions() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appendingPathComponent("paper-revision")
        let sessions = root.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let indexedID = UUID().uuidString
        let unindexedID = UUID().uuidString
        try
            "{\"type\":\"user\",\"cwd\":\"\(project.path)\",\"message\":{\"content\":\"Draft intro\"},\"timestamp\":\"2026-09-20T10:00:00Z\"}\n{\"type\":\"custom-title\",\"customTitle\":\"Final paper title\",\"timestamp\":\"2026-09-22T10:00:00Z\"}\n"
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

    /// The session this fixes was started from a New session tab with a screenshot pasted into its first prompt:
    /// unlisted, its tab stayed a New session row for good.
    @Test func aSessionWhoseFirstPromptCarriesAScreenshotIsListedWithItsFolderAndText() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let sessionID = UUID().uuidString
        let imageData = String(repeating: "A", count: 300_000)
        try folder.writeTranscript(
            sessionID,
            lines: [
                #"{"type":"mode","mode":"normal","sessionId":"\#(sessionID)"}"#,
                #"{"type":"file-history-snapshot","messageId":"m1"}"#,
                #"{"type":"user","cwd":"/Users/me/app","message":{"role":"user","content":[{"type":"text","text":"[Image #1] Is this a bug?"},{"type":"image","source":{"type":"base64","data":"\#(imageData)"}}]},"timestamp":"2026-10-10T07:00:00Z"}"#,
            ])

        let found = try #require(folder.discoveredConversationsBySessionID()[sessionID])

        #expect(found.projectPath == "/Users/me/app")
        #expect(found.suggestedTitle == "[Image #1] Is this a bug?")
    }

    @Test func sidechainSessionsAreLeftOut() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let markedInIndex = UUID().uuidString
        let markedInTranscript = UUID().uuidString
        let mainSession = UUID().uuidString
        try folder.writeTranscript(
            markedInIndex, lines: [#"{"type":"user","cwd":"/Users/me/app","message":{"content":"Marked in the index"}}"#])
        try folder.writeTranscript(
            markedInTranscript,
            lines: [#"{"type":"user","cwd":"/Users/me/app","isSidechain":true,"message":{"content":"Marked in the transcript"}}"#])
        try folder.writeTranscript(mainSession, lines: [#"{"type":"user","cwd":"/Users/me/app","message":{"content":"Main session"}}"#])
        try folder.writeIndex(#"{"entries":[{"sessionId":"\#(markedInIndex)","isSidechain":true}]}"#)

        #expect(try folder.discover().map(\.sessionID) == [mainSession])
    }

    @Test func subagentTranscriptsAreListedUnderTheSessionThatStartedThem() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let sessionID = UUID().uuidString
        try folder.writeTranscript(
            sessionID,
            lines: [
                #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Ship it"}}"#,
                #"{"type":"assistant","message":{"model":"claude-opus-4-8","content":[]}}"#,
            ])
        let subagents = folder.projectDirectory.appendingPathComponent("\(sessionID)/subagents")
        let workflow = subagents.appendingPathComponent("workflows/wf_1a2b")
        try FileManager.default.createDirectory(at: workflow, withIntermediateDirectories: true)
        try [
            #"{"type":"user","isSidechain":true,"agentId":"a1b2c3","cwd":"/Users/me/app","message":{"content":"Fix the refund bug, then test it"}}"#,
            #"{"type":"assistant","isSidechain":true,"agentId":"a1b2c3","message":{"model":"claude-haiku-4-5-20251001","content":[]}}"#,
        ].joined(separator: "\n").write(to: subagents.appendingPathComponent("agent-a1b2c3.jsonl"), atomically: true, encoding: .utf8)
        try #"{"agentType":"general-purpose","description":"Fix refund bug","spawnDepth":1}"#
            .write(to: subagents.appendingPathComponent("agent-a1b2c3.meta.json"), atomically: true, encoding: .utf8)
        try #"{"type":"user","isSidechain":true,"cwd":"/Users/me/app/api","message":{"content":"Research the API"}}"#
            .write(to: workflow.appendingPathComponent("agent-d4e5f6.jsonl"), atomically: true, encoding: .utf8)
        try #"{"type":"journal"}"#.write(to: workflow.appendingPathComponent("journal.jsonl"), atomically: true, encoding: .utf8)

        let found = try folder.discoveredConversationsBySessionID()

        #expect(Set(found.keys) == [sessionID, "a1b2c3", "d4e5f6"])
        #expect(found[sessionID]?.parentSessionID == nil)
        #expect(found[sessionID]?.model == SessionModel(id: "claude-opus-4-8"))
        let described = try #require(found["a1b2c3"])
        #expect(described.parentSessionID == sessionID)
        #expect(described.suggestedTitle == "Fix refund bug")
        #expect(described.projectPath == "/Users/me/app")
        #expect(described.sourceFile.lastPathComponent == "agent-a1b2c3.jsonl")
        #expect(described.model == SessionModel(id: "claude-haiku-4-5-20251001"))
        #expect(found["d4e5f6"]?.model == nil)
        #expect(found["d4e5f6"]?.parentSessionID == sessionID)
        #expect(found["d4e5f6"]?.suggestedTitle == "Research the API")
        #expect(found["d4e5f6"]?.projectPath == "/Users/me/app/api")
    }

    @Test func filesThatAreNotSessionTranscriptsAreLeftOut() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let prompt = #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Hi"}}"#
        try folder.writeTranscript("not-a-session-id", lines: [prompt])
        try prompt.write(to: folder.projectDirectory.appendingPathComponent("\(UUID().uuidString).txt"), atomically: true, encoding: .utf8)

        #expect(try folder.discover().isEmpty)
    }

    @Test func theProjectFolderComesFromTheIndexEntryThenTheTranscriptThenTheIndexsOriginalPath() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let namedByEntry = UUID().uuidString
        let namedByTranscript = UUID().uuidString
        let namedByOriginalPath = UUID().uuidString
        let noFolderAnywhere = UUID().uuidString
        let promptWithFolder = #"{"type":"user","cwd":"/from/transcript","message":{"content":"Hi"}}"#
        let promptWithoutFolder = #"{"type":"user","message":{"content":"Hi"}}"#
        try folder.writeTranscript(namedByEntry, lines: [promptWithFolder])
        try folder.writeTranscript(namedByTranscript, lines: [promptWithFolder])
        try folder.writeTranscript(namedByOriginalPath, lines: [promptWithoutFolder])
        try folder.writeIndex(
            #"{"originalPath":"/from/original-path","entries":[{"sessionId":"\#(namedByEntry)","projectPath":"/from/entry"}]}"#)

        let projectPaths = try folder.discoveredConversationsBySessionID().mapValues(\.projectPath)
        #expect(
            projectPaths == [
                namedByEntry: "/from/entry",
                namedByTranscript: "/from/transcript",
                namedByOriginalPath: "/from/original-path",
            ])

        try folder.writeIndex("{}")
        try folder.writeTranscript(noFolderAnywhere, lines: [promptWithoutFolder])
        #expect(try folder.discoveredConversationsBySessionID()[noFolderAnywhere] == nil)
    }

    /// `/cd` in Claude Code 2.1.296 moves the transcript into the new folder's project directory and writes a
    /// `relocated` line. The session belongs under that folder, ahead of the folder it started in or an index entry.
    @Test func aSessionMovedWithCdIsListedUnderTheFolderItMovedTo() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let sessionID = UUID().uuidString
        let startedInApp = [
            #"{"type":"user","cwd":"/Users/me/app","timestamp":"2026-10-13T10:00:00Z","message":{"content":"Start here"}}"#,
            #"{"type":"custom-title","customTitle":"Moving session"}"#,
        ]
        let startFile = try folder.writeTranscript(sessionID, lines: startedInApp)
        #expect(try folder.discoveredConversationsBySessionID()[sessionID]?.projectPath == "/Users/me/app")

        let movedProjectDirectory = folder.configurationDirectory.appendingPathComponent("projects/-Users-me-other-project")
        try FileManager.default.createDirectory(at: movedProjectDirectory, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: startFile)
        try
            (startedInApp + [
                #"{"type":"relocated","sessionId":"\#(sessionID)","relocatedCwd":"/Users/me/other/project"}"#,
                #"{"type":"user","cwd":"/Users/me/other/project","timestamp":"2026-10-13T10:05:00Z","message":{"content":"Keep going here"}}"#,
            ]).joined(separator: "\n").write(
                to: movedProjectDirectory.appendingPathComponent("\(sessionID).jsonl"), atomically: true, encoding: .utf8)
        try #"{"entries":[{"sessionId":"\#(sessionID)","projectPath":"/Users/me/app"}]}"#
            .write(to: movedProjectDirectory.appendingPathComponent("sessions-index.json"), atomically: true, encoding: .utf8)

        let moved = try #require(folder.discoveredConversationsBySessionID()[sessionID])
        #expect(moved.projectPath == "/Users/me/other/project")
        #expect(moved.suggestedTitle == "Moving session")
    }

    /// Claude Code keeps a session that entered a git worktree in the worktree folder's project directory, and lists
    /// it with `/resume` in the repository it entered the worktree from.
    @Test func listsASessionInAWorktreeUnderTheRepositoryItEnteredItFrom() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let sessionID = UUID().uuidString
        let worktreeProjectDirectory = folder.configurationDirectory
            .appendingPathComponent("projects/-Users-me-app--claude-worktrees-fix")
        try FileManager.default.createDirectory(at: worktreeProjectDirectory, withIntermediateDirectories: true)
        try [
            #"{"type":"user","cwd":"/Users/me/app","timestamp":"2026-10-15T10:00:00Z","message":{"content":"Fix it in a worktree"}}"#,
            #"{"type":"relocated","sessionId":"\#(sessionID)","relocatedCwd":"/Users/me/app/.claude/worktrees/fix"}"#,
            #"{"type":"worktree-state","worktreeSession":{"originalCwd":"/Users/me/app","worktreePath":"/Users/me/app/.claude/worktrees/fix","worktreeName":"fix"},"sessionId":"\#(sessionID)"}"#,
            #"{"type":"assistant","cwd":"/Users/me/app/.claude/worktrees/fix","timestamp":"2026-10-15T10:05:00Z","message":{"content":"Fixed"}}"#,
        ].joined(separator: "\n").write(
            to: worktreeProjectDirectory.appendingPathComponent("\(sessionID).jsonl"), atomically: true, encoding: .utf8)

        #expect(try folder.discoveredConversationsBySessionID()[sessionID]?.projectPath == "/Users/me/app")
    }

    /// Each line's `cwd` follows Claude's shell, which changes directory as it works. Only `/cd` moves the session.
    @Test func aShellThatChangesDirectoryLeavesTheSessionInItsFolder() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let sessionID = UUID().uuidString
        try folder.writeTranscript(
            sessionID,
            lines: [
                #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Build the web app"}}"#,
                #"{"type":"assistant","cwd":"/Users/me/app/web","message":{"content":"Built"}}"#,
                #"{"type":"user","cwd":"/Users/me/app/web/node_modules/pkg","message":{"content":"Check the package"}}"#,
            ])

        #expect(try folder.discoveredConversationsBySessionID()[sessionID]?.projectPath == "/Users/me/app")
    }

    /// Claude Code titles a session itself, in `ai-title` lines. That title comes after a name the user gave and
    /// before the first prompt, and a session that opens with a slash command is titled by its first real prompt.
    @Test func aGeneratedTitleComesAfterANameAndBeforeAPrompt() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let generated = UUID().uuidString
        let renamed = UUID().uuidString
        let commandFirst = UUID().uuidString
        let prompt = #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Transcript prompt"}}"#
        let command = #"{"type":"user","cwd":"/Users/me/app","message":{"content":"<command-name>/model</command-name>"}}"#
        let aiTitle = #"{"type":"ai-title","aiTitle":"Generated title"}"#
        try folder.writeTranscript(generated, lines: [command, prompt, #"{"type":"ai-title","aiTitle":"Early guess"}"#, aiTitle])
        try folder.writeTranscript(renamed, lines: [prompt, #"{"type":"custom-title","customTitle":"Transcript name"}"#, aiTitle])
        try folder.writeTranscript(commandFirst, lines: [command, prompt])

        let titles = try folder.discoveredConversationsBySessionID().mapValues(\.suggestedTitle)
        #expect(
            titles == [
                generated: "Generated title",
                renamed: "Transcript name",
                commandFirst: "Transcript prompt",
            ])
    }

    @Test func theTitleIsTheLatestCustomTitleThenTheIndexsNameThenAPrompt() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let renamedInTranscript = UUID().uuidString
        let renamedInIndex = UUID().uuidString
        let promptInIndex = UUID().uuidString
        let promptInTranscript = UUID().uuidString
        let commandInIndex = UUID().uuidString
        let untitled = UUID().uuidString
        let prompt = #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Transcript prompt"}}"#
        try folder.writeTranscript(renamedInTranscript, lines: [prompt, #"{"type":"custom-title","customTitle":"Transcript name"}"#])
        try folder.writeTranscript(renamedInIndex, lines: [prompt])
        try folder.writeTranscript(promptInIndex, lines: [prompt])
        try folder.writeTranscript(promptInTranscript, lines: [prompt])
        try folder.writeTranscript(
            commandInIndex,
            lines: [
                #"{"type":"user","cwd":"/Users/me/app","message":{"content":"<command-name>/model</command-name>"}}"#, prompt,
            ])
        // A tool result is a user record too, but holds nothing the user typed.
        try folder.writeTranscript(
            untitled, lines: [#"{"type":"user","cwd":"/Users/me/app","message":{"content":[{"type":"tool_result","content":"ok"}]}}"#])
        try folder.writeIndex(
            #"""
            {"entries":[
              {"sessionId":"\#(renamedInTranscript)","customTitle":"Index name","firstPrompt":"Index prompt"},
              {"sessionId":"\#(renamedInIndex)","customTitle":"Index name","firstPrompt":"Index prompt"},
              {"sessionId":"\#(promptInIndex)","firstPrompt":"Index prompt"},
              {"sessionId":"\#(commandInIndex)","firstPrompt":"<command-name>/model</command-name>"}
            ]}
            """#)

        let titles = try folder.discoveredConversationsBySessionID().mapValues(\.suggestedTitle)
        #expect(
            titles == [
                renamedInTranscript: "Transcript name",
                renamedInIndex: "Index name",
                promptInIndex: "Index prompt",
                promptInTranscript: "Transcript prompt",
                commandInIndex: "Transcript prompt",
                untitled: ConversationMetadata.untitledConversationTitle,
            ])
    }

    /// Only the start and end of a long transcript are read, so a custom title set near its start is not the latest
    /// one found. It still beats the index's prompt, but not the index's name.
    @Test func aCustomTitleNearTheStartOfALongTranscriptComesAfterTheIndexsName() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let alsoNamedInIndex = UUID().uuidString
        let onlyPromptInIndex = UUID().uuidString
        let filler = Array(repeating: #"{"type":"assistant"}"#, count: 13_000)
        #expect(filler.joined(separator: "\n").utf8.count > ClaudeTranscriptTail.maximumByteCount)
        let longTranscript =
            [
                #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Transcript prompt"}}"#,
                #"{"type":"custom-title","customTitle":"Early name"}"#,
            ] + filler
        try folder.writeTranscript(alsoNamedInIndex, lines: longTranscript)
        try folder.writeTranscript(onlyPromptInIndex, lines: longTranscript)
        try folder.writeIndex(
            #"""
            {"entries":[
              {"sessionId":"\#(alsoNamedInIndex)","customTitle":"Index name"},
              {"sessionId":"\#(onlyPromptInIndex)","firstPrompt":"Index prompt"}
            ]}
            """#)

        let titles = try folder.discoveredConversationsBySessionID().mapValues(\.suggestedTitle)
        #expect(titles == [alsoNamedInIndex: "Index name", onlyPromptInIndex: "Early name"])
    }

    @Test func updatedAtIsTheNewerOfTheIndexAndTranscriptTimesOrElseTheFileDate() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let transcriptIsNewer = UUID().uuidString
        let indexIsNewer = UUID().uuidString
        let neitherHasATime = UUID().uuidString
        let promptAtEleven = #"{"type":"user","cwd":"/Users/me/app","timestamp":"2026-09-24T11:00:00Z","message":{"content":"Hi"}}"#
        try folder.writeTranscript(transcriptIsNewer, lines: [promptAtEleven])
        try folder.writeTranscript(indexIsNewer, lines: [promptAtEleven])
        let untimedFile = try folder.writeTranscript(
            neitherHasATime, lines: [#"{"type":"user","cwd":"/Users/me/app","message":{"content":"Hi"}}"#])
        let fileDate = Date(timeIntervalSince1970: 1_790_000_000)
        try FileManager.default.setAttributes([.modificationDate: fileDate], ofItemAtPath: untimedFile.path)
        try folder.writeIndex(
            #"""
            {"entries":[
              {"sessionId":"\#(transcriptIsNewer)","modified":"2026-09-24T10:00:00Z"},
              {"sessionId":"\#(indexIsNewer)","modified":"2026-09-24T12:00:00Z"}
            ]}
            """#)

        let updatedAt = try folder.discoveredConversationsBySessionID().mapValues(\.updatedAt)
        #expect(updatedAt[transcriptIsNewer] == ConversationMetadata.date("2026-09-24T11:00:00Z"))
        #expect(updatedAt[indexIsNewer] == ConversationMetadata.date("2026-09-24T12:00:00Z"))
        #expect(updatedAt[neitherHasATime] == fileDate)
    }

    @Test func aTranscriptClaudeWroteMoreToSinceTheLastScanIsReadAgain() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let sessionID = UUID().uuidString
        let firstPrompt = #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Draft intro"}}"#
        try folder.writeTranscript(sessionID, lines: [firstPrompt])
        #expect(try folder.discover().first?.suggestedTitle == "Draft intro")

        try folder.writeTranscript(sessionID, lines: [firstPrompt, #"{"type":"custom-title","customTitle":"Renamed with /rename"}"#])

        #expect(try folder.discover().first?.suggestedTitle == "Renamed with /rename")
    }
}
