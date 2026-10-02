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

    @Test func sidechainSessionsAreLeftOut() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let markedInIndex = UUID().uuidString
        let markedInTranscript = UUID().uuidString
        let mainSession = UUID().uuidString
        try folder.writeTranscript(markedInIndex, lines: [#"{"type":"user","cwd":"/Users/me/app","message":{"content":"Marked in the index"}}"#])
        try folder.writeTranscript(markedInTranscript, lines: [#"{"type":"user","cwd":"/Users/me/app","isSidechain":true,"message":{"content":"Marked in the transcript"}}"#])
        try folder.writeTranscript(mainSession, lines: [#"{"type":"user","cwd":"/Users/me/app","message":{"content":"Main session"}}"#])
        try folder.writeIndex(#"{"entries":[{"sessionId":"\#(markedInIndex)","isSidechain":true}]}"#)

        #expect(try folder.discover().map(\.sessionID) == [mainSession])
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
        try folder.writeIndex(#"{"originalPath":"/from/original-path","entries":[{"sessionId":"\#(namedByEntry)","projectPath":"/from/entry"}]}"#)

        let projectPaths = try folder.discoveredConversationsBySessionID().mapValues(\.projectPath)
        #expect(projectPaths == [
            namedByEntry: "/from/entry",
            namedByTranscript: "/from/transcript",
            namedByOriginalPath: "/from/original-path",
        ])

        try folder.writeIndex("{}")
        try folder.writeTranscript(noFolderAnywhere, lines: [promptWithoutFolder])
        #expect(try folder.discoveredConversationsBySessionID()[noFolderAnywhere] == nil)
    }

    @Test func theTitleIsTheLatestCustomTitleThenTheIndexsNameThenAPrompt() throws {
        let folder = try ClaudeProjectFolderFixture()
        defer { folder.remove() }
        let renamedInTranscript = UUID().uuidString
        let renamedInIndex = UUID().uuidString
        let promptInIndex = UUID().uuidString
        let promptInTranscript = UUID().uuidString
        let untitled = UUID().uuidString
        let prompt = #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Transcript prompt"}}"#
        try folder.writeTranscript(renamedInTranscript, lines: [prompt, #"{"type":"custom-title","customTitle":"Transcript name"}"#])
        try folder.writeTranscript(renamedInIndex, lines: [prompt])
        try folder.writeTranscript(promptInIndex, lines: [prompt])
        try folder.writeTranscript(promptInTranscript, lines: [prompt])
        try folder.writeTranscript(untitled, lines: [#"{"type":"user","cwd":"/Users/me/app","message":{"content":[{"type":"text","text":"Sent as parts"}]}}"#])
        try folder.writeIndex(#"""
        {"entries":[
          {"sessionId":"\#(renamedInTranscript)","customTitle":"Index name","firstPrompt":"Index prompt"},
          {"sessionId":"\#(renamedInIndex)","customTitle":"Index name","firstPrompt":"Index prompt"},
          {"sessionId":"\#(promptInIndex)","firstPrompt":"Index prompt"}
        ]}
        """#)

        let titles = try folder.discoveredConversationsBySessionID().mapValues(\.suggestedTitle)
        #expect(titles == [
            renamedInTranscript: "Transcript name",
            renamedInIndex: "Index name",
            promptInIndex: "Index prompt",
            promptInTranscript: "Transcript prompt",
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
        let longTranscript = [
            #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Transcript prompt"}}"#,
            #"{"type":"custom-title","customTitle":"Early name"}"#,
        ] + filler
        try folder.writeTranscript(alsoNamedInIndex, lines: longTranscript)
        try folder.writeTranscript(onlyPromptInIndex, lines: longTranscript)
        try folder.writeIndex(#"""
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
        let untimedFile = try folder.writeTranscript(neitherHasATime, lines: [#"{"type":"user","cwd":"/Users/me/app","message":{"content":"Hi"}}"#])
        let fileDate = Date(timeIntervalSince1970: 1_790_000_000)
        try FileManager.default.setAttributes([.modificationDate: fileDate], ofItemAtPath: untimedFile.path)
        try folder.writeIndex(#"""
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
