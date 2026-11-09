import Foundation
import Testing
@testable import JustSessions

/// A tab's outline as its file changes (TAB-10, PERF-89): extended from the last block's record when the file grew, read
/// in full when it was cut, rewritten, or left its Pi branch; and ⌘D's newest message (TRM-74).
struct ConversationOutlineReaderTests {
    @Test func anEarlierAntigravityStepRewriteRebuildsTheOutline() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: directory)
        try fixture.appendPrompt("Unchanged final prompt", index: 1)
        let reader = ConversationOutlineReader(fixture.conversation)
        _ = try await reader.update()
        try AntigravitySessionFixture.execute(["DELETE FROM steps WHERE idx = 0"], at: fixture.databaseFile)
        try fixture.appendPrompt("Rewritten first prompt", index: 0)
        let updated = try #require(try await reader.update())
        #expect(updated.blocks.first?.snippet == "Rewritten first prompt")
        #expect(updated == (try await Self.fullRead(fixture.conversation)))
    }

    @Test(arguments: [false, true])
    func anEarlierRewriteIsDetectedEvenAfterReadingTheLatestMessage(atomic: Bool) async throws {
        let fixture = try TranscriptPagingFixture(count: 600)
        defer { fixture.remove() }
        let reader = ConversationOutlineReader(fixture.conversation)
        _ = try await reader.update()
        let original = String(decoding: try Data(contentsOf: fixture.file), as: UTF8.self)
        let replacement = Data(original.replacingOccurrences(of: "Message 0,", with: "Rewritten first message 0,").utf8)
        try replacement.write(to: fixture.file, options: atomic ? .atomic : [])
        // ⌘D shares the source but must not consume the outline's rewrite detection.
        #expect(try await reader.latestMessage()?.id == TranscriptPageIdentity.entryID(record: 599, part: 0))
        let updated = try #require(try await reader.update())
        #expect(updated.blocks.first?.snippet.hasPrefix("Rewritten first message 0") == true)
        #expect(updated == (try await Self.fullRead(fixture.conversation)))
    }

    @Test func anEarlierOpenCodePartRewriteRebuildsTheOutline() async throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_earlier_rewrite")
        try database.addUserPrompt("msg_a", session: "ses_earlier_rewrite", createdAt: 1, text: "Original first")
        try database.addAssistantReply("msg_b", session: "ses_earlier_rewrite", createdAt: 2, text: "Unchanged last")
        let conversation = Conversation.fixture(provider: .opencode, sessionID: "ses_earlier_rewrite", sourceFile: database.file)
        let reader = ConversationOutlineReader(conversation)
        _ = try await reader.update()
        try database.execute("UPDATE part SET data = ? WHERE message_id = ?", [#"{"type":"text","text":"Rewritten first"}"#, "msg_a"])
        _ = try await reader.latestMessage()
        let updated = try #require(try await reader.update())
        #expect(updated.blocks.first?.snippet == "Rewritten first")
        #expect(updated == (try await Self.fullRead(conversation)))
    }

    @Test func anAppendExtendsAsAFullReadWould() async throws {
        let fixture = try TranscriptPagingFixture(count: 600)
        defer { fixture.remove() }
        let reader = ConversationOutlineReader(fixture.conversation)
        let before = try #require(try await reader.update())
        #expect(before.blocks.count == 600)
        try fixture.append(TranscriptPagingFixture.data(count: 603).suffix(from: try Self.byteCount(of: fixture.file)))
        let after = try #require(try await reader.update())
        #expect(after.blocks.count == 603)
        #expect(after == (try await Self.fullRead(fixture.conversation)))
    }

    @Test func aSecondUpdateWithNoChangeReturnsNil() async throws {
        let fixture = try TranscriptPagingFixture(count: 40)
        defer { fixture.remove() }
        let reader = ConversationOutlineReader(fixture.conversation)
        #expect(try await reader.update() != nil)
        #expect(await !reader.hasChanged())
        #expect(try await reader.update() == nil)
    }

    @Test func aCompletedLastLineIsReadAgain() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let complete = TranscriptPagingFixture.data(count: 50, lineCounts: [49: 5])
        try Data(complete.dropLast(10)).write(to: fixture.file)
        let reader = ConversationOutlineReader(fixture.conversation)
        let partial = try #require(try await reader.update())
        #expect(partial.blocks.count == 49)
        try complete.write(to: fixture.file)
        let completed = try #require(try await reader.update())
        #expect(completed.blocks.count == 50)
        #expect(completed.blocks.last!.lineWidths.count > partial.blocks.last!.lineWidths.count)
        #expect(completed.blocks.last!.snippet.hasPrefix("Message 49, line 0"))
        #expect(completed == (try await Self.fullRead(fixture.conversation)))
    }

    @Test func aToolRunGrowingAtTheEndStaysOneBlock() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let codex = SampleTranscriptLines.codex
        try SampleTranscriptLines.fileContents([codex[1], codex[6]] + Array(repeating: codex[2], count: 10)).write(to: fixture.file)
        let reader = ConversationOutlineReader(fixture.conversation)
        let before = try #require(try await reader.update())
        try fixture.append(SampleTranscriptLines.fileContents(Array(repeating: codex[2], count: 5)))
        let after = try #require(try await reader.update())
        #expect(after.blocks.count == before.blocks.count)
        #expect(before.blocks.last?.toolCallCount == 10)
        #expect(after.blocks.last?.toolCallCount == 15)
        #expect(after == (try await Self.fullRead(fixture.conversation)))
    }

    /// Claude's reply and its first tool call share a record, so the resume record is the reply's.
    @Test func aSharedClaudeRecordIsNotCountedTwice() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let claude = SampleTranscriptLines.claude
        try SampleTranscriptLines.fileContents(Array(claude[0...2])).write(to: fixture.file)
        let conversation = Conversation.fixture(provider: .claude, sourceFile: fixture.file)
        let reader = ConversationOutlineReader(conversation)
        _ = try await reader.update()
        try fixture.append(SampleTranscriptLines.fileContents([claude[3]]))
        let afterResult = try await reader.update()
        let fullAfterResult = try await Self.fullRead(conversation)
        #expect(afterResult == nil || afterResult == fullAfterResult)
        try fixture.append(SampleTranscriptLines.fileContents(Array(claude[4...5])))
        let afterReplies = try #require(try await reader.update())
        #expect(afterReplies == (try await Self.fullRead(conversation)))
        #expect(afterReplies.blocks.map(\.kind) == [.user, .assistant, .toolRun, .assistant, .user])
    }

    @Test func aTruncatedFileIsReadInFull() async throws {
        let fixture = try TranscriptPagingFixture(count: 600)
        defer { fixture.remove() }
        let reader = ConversationOutlineReader(fixture.conversation)
        _ = try await reader.update()
        try TranscriptPagingFixture.data(count: 300).write(to: fixture.file)
        let truncated = try #require(try await reader.update())
        #expect(truncated.blocks.count == 300)
        #expect(truncated == (try await Self.fullRead(fixture.conversation)))
    }

    @Test func aRewrittenLastRecordIsReadInFull() async throws {
        let fixture = try TranscriptPagingFixture(count: 600)
        defer { fixture.remove() }
        let reader = ConversationOutlineReader(fixture.conversation)
        _ = try await reader.update()
        let original = String(decoding: try Data(contentsOf: fixture.file), as: UTF8.self)
        try Data(original.replacingOccurrences(of: "Message 599, line 0", with: "Rewrote 599, line 0").utf8).write(to: fixture.file)
        let sameLength = try #require(try await reader.update())
        #expect(sameLength.blocks.last?.snippet.hasPrefix("Rewrote 599") == true)
        #expect(sameLength == (try await Self.fullRead(fixture.conversation)))

        // Every record rewritten, one longer: the record read again no longer starts as its block did.
        try Data(original.replacingOccurrences(of: "Message ", with: "Edited ").replacingOccurrences(of: "Edited 599", with: "Edited 599, longer").utf8)
            .write(to: fixture.file)
        let rewritten = try #require(try await reader.update())
        #expect(rewritten.blocks.first?.snippet.hasPrefix("Edited 0") == true)
        #expect(rewritten == (try await Self.fullRead(fixture.conversation)))
    }

    /// An SSH mirror's rsync writes a new file and renames it over the old one.
    @Test func aReplacedCopyWithOneMoreRecordExtends() async throws {
        let fixture = try TranscriptPagingFixture(count: 600)
        defer { fixture.remove() }
        let reader = ConversationOutlineReader(fixture.conversation)
        _ = try await reader.update()
        let inode = ConversationOutlineChangeStamp(of: fixture.conversation).file?.inode
        let copy = fixture.directory.appendingPathComponent("copy.jsonl")
        try TranscriptPagingFixture.data(count: 601).write(to: copy)
        _ = try FileManager.default.replaceItemAt(fixture.file, withItemAt: copy)
        #expect(ConversationOutlineChangeStamp(of: fixture.conversation).file?.inode != inode)
        #expect(await reader.hasChanged())
        let replaced = try #require(try await reader.update())
        #expect(replaced.blocks.count == 601)
        #expect(replaced == (try await Self.fullRead(fixture.conversation)))
    }

    @Test func leavingAPiBranchIsReadInFull() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        try SampleTranscriptLines.fileContents(SampleTranscriptLines.pi).write(to: fixture.file)
        let conversation = Conversation.fixture(provider: .pi, sourceFile: fixture.file)
        let reader = ConversationOutlineReader(conversation)
        let before = try #require(try await reader.update())
        #expect(before.blocks.last?.snippet == "Thanks")
        let branch = #"{"type":"message","id":"b1","parentId":"a2","timestamp":"2026-09-24T10:00:09.000Z","message":{"role":"user","content":"Try another way","timestamp":1758708009000}}"#
        try fixture.append(SampleTranscriptLines.fileContents([branch]))
        let after = try #require(try await reader.update())
        #expect(after.blocks.last?.snippet == "Try another way")
        #expect(!after.blocks.contains { $0.snippet == "Thanks" })
        #expect(after == (try await Self.fullRead(conversation)))
    }

    @Test func aSubagentTranscriptKeepsItsSidechain() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        try SampleTranscriptLines.fileContents([
            #"{"type":"user","isSidechain":true,"message":{"content":"Fix the refund bug"}}"#,
            #"{"type":"assistant","isSidechain":true,"message":{"content":[{"type":"text","text":"Fixed"}]}}"#,
        ]).write(to: fixture.file)
        let subagent = Conversation.fixture(provider: .claude, sourceFile: fixture.file, parentSessionID: UUID().uuidString)
        let outline = try #require(try await ConversationOutlineReader(subagent).update())
        #expect(outline.blocks.map(\.kind) == [.user, .assistant])
        #expect(outline.blocks.map(\.snippet) == ["Fix the refund bug", "Fixed"])
    }

    @Test func anOpenCodeOutlineMatchesItsPages() async throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        try database.addSession("ses_map")
        try database.addUserPrompt("msg_a", session: "ses_map", createdAt: 1, text: "First")
        try database.addMessage("msg_b", session: "ses_map", createdAt: 2, data: ["role": "assistant"])
        try database.addPart("prt_b1", message: "msg_b", session: "ses_map", data: [
            "type": "tool", "tool": "bash", "state": ["status": "completed", "input": ["command": "swift test"]],
        ])
        try database.addPart("prt_b2", message: "msg_b", session: "ses_map", data: ["type": "text", "text": "Reply"])
        try database.addUserPrompt("msg_c", session: "ses_map", createdAt: 3, text: "Thanks")
        let conversation = Conversation.fixture(provider: .opencode, sessionID: "ses_map", sourceFile: database.file)
        let reader = ConversationOutlineReader(conversation)
        let outline = try #require(try await reader.update())

        let source = TranscriptPageSource(file: database.file, provider: .opencode, sessionID: "ses_map")
        var pages = [try await source.read(.first)]
        while pages.last!.hasLater { pages.append(try await source.read(.after(pages.last!.records.upperBound))) }
        #expect(outline.blocks.map(\.entryID) == pages.flatMap(\.entries).filter(ConversationOutlineBuilder.makesBlock).map(\.id))
        #expect(outline.blocks.map(\.kind) == [.user, .toolRun, .assistant, .user])

        try database.addAssistantReply("msg_d", session: "ses_map", createdAt: 4, text: "You're welcome")
        let extended = try #require(try await reader.update())
        #expect(extended.blocks.count == outline.blocks.count + 1)
        #expect(extended == (try await Self.fullRead(conversation)))
    }

    @Test func theLatestMessageSkipsTrailingToolCallsAndNotes() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let codex = SampleTranscriptLines.codex
        try SampleTranscriptLines.fileContents([codex[0], codex[1], codex[6], codex[2], codex[3], codex[7]]).write(to: fixture.file)
        let latest = try #require(try await ConversationOutlineReader(fixture.conversation).latestMessage())
        let readers = try await TranscriptPageSource(file: fixture.file, provider: .codex).read(.latest)
        #expect(readers.entries.last.map { MessageBookmark.Kind($0.content) } == .some(nil))
        #expect(latest.content == .assistantMessage("Done. 完成 ✅"))
        #expect(latest.id == readers.entries.first { $0.content == latest.content }?.id)
    }

    @Test func theLatestMessagePagesBackPastALongToolRun() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let codex = SampleTranscriptLines.codex
        try SampleTranscriptLines.fileContents([codex[1], codex[6]] + Array(repeating: codex[2], count: 600)).write(to: fixture.file)
        let latest = try await ConversationOutlineReader(fixture.conversation).latestMessage()
        #expect(latest?.content == .assistantMessage("Done. 完成 ✅"))
        #expect(latest?.id == TranscriptPageIdentity.entryID(record: 1, part: 0))
    }

    @Test func aSessionWithoutMessagesHasNoLatestMessage() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let codex = SampleTranscriptLines.codex
        try SampleTranscriptLines.fileContents([codex[0]] + Array(repeating: codex[2], count: 20)).write(to: fixture.file)
        #expect(try await ConversationOutlineReader(fixture.conversation).latestMessage() == nil)
    }

    static func fullRead(_ conversation: Conversation) async throws -> ConversationOutline {
        try #require(try await ConversationOutlineReader(conversation).update())
    }

    private static func byteCount(of file: URL) throws -> Int {
        try FileManager.default.attributesOfItem(atPath: file.path)[.size] as! Int
    }
}

extension TranscriptPagingFixture {
    /// Appends to the file in place, keeping its inode, as a CLI writes its log.
    func append(_ data: Data) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }
}
