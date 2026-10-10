import Foundation
import Testing
@testable import JustSessions

struct OpenCodeTranscriptPagingTests {
    @Test func pagesShowTheSameEntriesAsTheFullRead() async throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001", revert: ["messageID": "msg_d"])
        try database.addSession("ses_session0002")
        try database.addUserPrompt("msg_a", session: "ses_session0001", createdAt: 1, text: "First")
        try database.addMessage("msg_b", session: "ses_session0001", createdAt: 2, data: ["role": "assistant"])
        try database.addPart("prt_b1", message: "msg_b", session: "ses_session0001", data: [
            "type": "tool", "tool": "bash", "state": ["status": "completed", "input": ["command": "swift test"]],
        ])
        try database.addPart("prt_b2", message: "msg_b", session: "ses_session0001", data: ["type": "text", "text": "Reply"])
        try database.addUserPrompt("msg_c", session: "ses_session0001", createdAt: 3, text: "Last kept")
        try database.addUserPrompt("msg_d", session: "ses_session0001", createdAt: 4, text: "Undone")
        try database.addUserPrompt("msg_other", session: "ses_session0002", createdAt: 1, text: "Another session")
        var limits = TranscriptPageLimits()
        limits.targetEntryCount = 1
        let source = TranscriptPageSource(file: database.file, provider: .opencode, sessionID: "ses_session0001", limits: limits)

        var pages = [try await source.read(.latest)]
        while let first = pages.first, first.hasEarlier {
            pages.insert(try await source.read(.before(first.records.lowerBound)), at: 0)
        }

        #expect(pages.flatMap(\.entries).map(\.content) == (try fixture.read("ses_session0001")).entries.map(\.content))
        #expect(pages.flatMap(\.entries).map(\.content).last == .note(OpenCodeTranscriptReader.undoneMessagesNoteText))
        #expect(pages.contains { $0.entries.map(\.content) == [.toolCalls(["bash · swift test"]), .assistantMessage("Reply")] })
        #expect(pages.last?.hasLater == false)
    }

    /// Each message is a record, so an unreadable one keeps its place with no entries, and the pages still show what
    /// the full read shows.
    @Test func unreadableMessagesKeepTheirRecordsWithoutEntries() async throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001")
        try database.addUserPrompt("msg_a", session: "ses_session0001", createdAt: 1, text: "First")
        try database.addMessage("msg_b", session: "ses_session0001", createdAt: 2, rawData: "{not json")
        try database.addMessage("msg_c", session: "ses_session0001", createdAt: 3, data: ["role": "system"])
        try database.addAssistantReply("msg_d", session: "ses_session0001", createdAt: 4, text: "Reply")
        var limits = TranscriptPageLimits()
        limits.targetEntryCount = 1
        let source = TranscriptPageSource(file: database.file, provider: .opencode, sessionID: "ses_session0001", limits: limits)

        let latest = try await source.read(.latest)
        let first = try await source.read(.before(latest.records.lowerBound))

        #expect(latest.totalRecordCount == 4)
        #expect(latest.entries.map(\.content) == [.assistantMessage("Reply")])
        #expect(latest.entries.map(\.id) == [TranscriptPageIdentity.entryID(record: 3, part: 0)])
        #expect(first.entries.map(\.content) == [.userMessage("First")])
        #expect(!first.hasEarlier)
    }

    /// OpenCode rewrites a reply's data in place, such as when it fails. Each page reads its messages anew.
    @Test func aReplyChangedInPlaceShowsOnTheNextRead() async throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_session0001")
        try database.addUserPrompt("msg_a", session: "ses_session0001", createdAt: 1, text: "Run it")
        try database.addAssistantReply("msg_b", session: "ses_session0001", createdAt: 2, text: "Running")
        let source = TranscriptPageSource(file: database.file, provider: .opencode, sessionID: "ses_session0001")
        #expect(try await source.read(.latest).entries.map(\.content) == [.userMessage("Run it"), .assistantMessage("Running")])

        try database.execute(
            "UPDATE message SET data = ? WHERE id = 'msg_b'",
            [#"{"role":"assistant","error":{"name":"APIError","data":{"message":"Rate limited"}}}"#]
        )

        #expect(try await source.read(.latest).entries.map(\.content) == [
            .userMessage("Run it"), .assistantMessage("Running"), .note("Rate limited"),
        ])
    }

    @Test func aSessionIsRequiredToPageOpenCodesDatabase() async throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let source = TranscriptPageSource(file: fixture.database.file, provider: .opencode)
        await #expect(throws: OpenCodeDatabaseError.self) { try await source.read(.latest) }
    }
}
