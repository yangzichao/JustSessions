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

    @Test func aSessionIsRequiredToPageOpenCodesDatabase() async throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let source = TranscriptPageSource(file: fixture.database.file, provider: .opencode)
        await #expect(throws: OpenCodeDatabaseError.self) { try await source.read(.latest) }
    }
}
