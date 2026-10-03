import Foundation
import Testing
@testable import JustSessions

struct OpenCodeTranscriptReaderTests {
    @Test func showsPromptsRepliesAndToolCallsButNotTheTextOpenCodeAdds() throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001")
        try database.addUserPrompt("msg_a", session: "ses_session0001", createdAt: 1_790_000_000_000, text: "Read @notes.txt")
        try database.addPart("prt_msg_a_zsynthetic", message: "msg_a", session: "ses_session0001", data: [
            "type": "text", "text": "Called the Read tool with notes.txt", "synthetic": true,
        ])
        try database.addMessage("msg_b", session: "ses_session0001", createdAt: 1_790_000_001_000, data: ["role": "assistant"])
        try database.addPart("prt_b1", message: "msg_b", session: "ses_session0001", data: ["type": "step-start"])
        try database.addPart("prt_b2", message: "msg_b", session: "ses_session0001", data: ["type": "reasoning", "text": "Thinking"])
        try database.addPart("prt_b3", message: "msg_b", session: "ses_session0001", data: [
            "type": "tool", "tool": "read",
            "state": ["status": "completed", "input": ["filePath": "/Users/me/app/notes.txt"], "output": "hello world"],
        ])
        try database.addPart("prt_b4", message: "msg_b", session: "ses_session0001", data: ["type": "text", "text": "It says hello world."])
        try database.addPart("prt_b5", message: "msg_b", session: "ses_session0001", data: ["type": "step-finish", "reason": "stop"])

        let transcript = try fixture.read("ses_session0001")

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Read @notes.txt"),
            .toolCalls(["read · /Users/me/app/notes.txt"]),
            .assistantMessage("It says hello world."),
        ])
        #expect(transcript.entries.first?.timestamp == Date(timeIntervalSince1970: 1_790_000_000))
    }

    @Test func readsOnlyTheRequestedSessionInTheOrderOpenCodeShows() throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001")
        try database.addSession("ses_session0002")
        // Same creation time: OpenCode orders by id next.
        try database.addAssistantReply("msg_c", session: "ses_session0001", createdAt: 2, text: "Third")
        try database.addUserPrompt("msg_b", session: "ses_session0001", createdAt: 1, text: "Second")
        try database.addUserPrompt("msg_a", session: "ses_session0001", createdAt: 1, text: "First")
        try database.addUserPrompt("msg_other", session: "ses_session0002", createdAt: 1, text: "Another session")

        #expect(try fixture.read("ses_session0001").entries.map(\.content) == [
            .userMessage("First"), .userMessage("Second"), .assistantMessage("Third"),
        ])
    }

    @Test func undoneMessagesAreReplacedByANote() throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001", revert: ["messageID": "msg_b", "partID": "prt_msg_b_text"])
        try database.addUserPrompt("msg_a", session: "ses_session0001", createdAt: 1, text: "Kept")
        try database.addUserPrompt("msg_b", session: "ses_session0001", createdAt: 2, text: "Undone")
        try database.addAssistantReply("msg_c", session: "ses_session0001", createdAt: 3, text: "Also undone")

        #expect(try fixture.read("ses_session0001").entries.map(\.content) == [
            .userMessage("Kept"), .note(OpenCodeTranscriptReader.undoneMessagesNoteText),
        ])
    }

    @Test func compactionShowsANoteInsteadOfItsSummary() throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001")
        try database.addUserPrompt("msg_a", session: "ses_session0001", createdAt: 1, text: "Before")
        try database.addMessage("msg_b", session: "ses_session0001", createdAt: 2, data: ["role": "user"])
        try database.addPart("prt_b", message: "msg_b", session: "ses_session0001", data: ["type": "compaction", "auto": true])
        try database.addMessage("msg_c", session: "ses_session0001", createdAt: 3, data: ["role": "assistant", "summary": true])
        try database.addPart("prt_c", message: "msg_c", session: "ses_session0001", data: ["type": "text", "text": "Summary for the model"])
        try database.addUserPrompt("msg_d", session: "ses_session0001", createdAt: 4, text: "After")

        #expect(try fixture.read("ses_session0001").entries.map(\.content) == [
            .userMessage("Before"), .note(TranscriptBuilder.compactionNoteText), .userMessage("After"),
        ])
    }

    @Test func errorsShowAsNotesExceptWhenTheUserStoppedTheReply() throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001")
        try database.addMessage("msg_a", session: "ses_session0001", createdAt: 1, data: [
            "role": "assistant", "error": ["name": "APIError", "data": ["message": "Rate limit exceeded"]],
        ])
        try database.addMessage("msg_b", session: "ses_session0001", createdAt: 2, data: [
            "role": "assistant", "error": ["name": "ProviderAuthError", "data": [:]],
        ])
        try database.addMessage("msg_c", session: "ses_session0001", createdAt: 3, data: [
            "role": "assistant", "error": ["name": "MessageAbortedError", "data": ["message": "Aborted"]],
        ])
        try database.addPart("prt_c", message: "msg_c", session: "ses_session0001", data: ["type": "text", "text": "Partial"])

        #expect(try fixture.read("ses_session0001").entries.map(\.content) == [
            .note("Rate limit exceeded"), .note("ProviderAuthError"), .assistantMessage("Partial"),
        ])
    }

    @Test func attachmentsTheTextDoesNotMentionShowAsLabels() throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001")
        try database.addUserPrompt("msg_a", session: "ses_session0001", createdAt: 1, text: "Look at [Image 1] and @a.swift")
        let dataURL = "data:image/png;base64,\(String(repeating: "A", count: 64))"
        try database.addPart("prt_msg_a_y1", message: "msg_a", session: "ses_session0001", data: [
            "type": "file", "mime": "image/png", "url": dataURL, "source": ["type": "file", "path": "image.png"],
        ])
        try database.addPart("prt_msg_a_y2", message: "msg_a", session: "ses_session0001", data: [
            "type": "file", "mime": "image/jpeg", "url": dataURL,
        ])
        try database.addPart("prt_msg_a_y3", message: "msg_a", session: "ses_session0001", data: [
            "type": "file", "mime": "application/pdf", "filename": "spec.pdf", "url": "file:///spec.pdf",
        ])
        try database.addPart("prt_msg_a_y4", message: "msg_a", session: "ses_session0001", data: [
            "type": "file", "mime": "text/plain", "url": "file:///notes",
        ])

        #expect(try fixture.read("ses_session0001").entries.map(\.content) == [
            .userMessage("Look at [Image 1] and @a.swift\n\n[Image]\n\n[File: spec.pdf]\n\n[File]"),
        ])
    }

    @Test func unreadableMessagesAndPartsAreSkipped() throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001")
        try database.addMessage("msg_a", session: "ses_session0001", createdAt: 1, rawData: "{not json")
        try database.addUserPrompt("msg_b", session: "ses_session0001", createdAt: 2, text: "Readable")
        try database.execute("INSERT INTO part VALUES ('prt_msg_b_z', 'msg_b', 'ses_session0001', 1, 1, '{broken')")
        try database.addMessage("msg_c", session: "ses_session0001", createdAt: 3, data: ["role": "system"])

        #expect(try fixture.read("ses_session0001").entries.map(\.content) == [.userMessage("Readable")])
    }
}

struct OpenCodeTranscriptReaderFixture {
    let root: URL
    let database: OpenCodeDatabaseFixture

    init() throws {
        root = try makeTemporaryDirectory()
        database = try OpenCodeDatabaseFixture(file: root.appendingPathComponent("opencode.db"))
    }

    func read(_ sessionID: String) throws -> TranscriptContent {
        try OpenCodeTranscriptReader().read(database.file, sessionID: sessionID)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
