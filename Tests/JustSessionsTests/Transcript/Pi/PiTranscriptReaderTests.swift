import Foundation
import Testing
@testable import JustSessions

struct PiTranscriptReaderTests {
    @Test func showsALinearSessionWithToolCallsMergedAndToolResultsLeftOut() throws {
        let transcript = try read([
            Self.entry("model_change", "m0", parent: nil, #""provider":"anthropic","modelId":"claude-sonnet-4-5""#),
            Self.message("s1", parent: "m0", #"{"role":"system","content":"You are Pi","sections":{"preamble":"hidden"},"timestamp":1}"#),
            Self.entry("thinking_level_change", "k1", parent: "s1", #""thinkingLevel":"high""#),
            Self.user("u1", parent: "k1", "Fix the build"),
            Self.message("a1", parent: "u1", #"{"role":"assistant","content":["#
                + #"{"type":"thinking","thinking":"hidden plan"},{"type":"text","text":"Looking at it."},"#
                + #"{"type":"toolCall","id":"t1","name":"bash","arguments":{"command":"swift build\nextra line","timeout":60}}"#
                + #"],"stopReason":"toolUse","timestamp":2}"#),
            Self.toolResult("r1", parent: "a1", toolCallID: "t1"),
            Self.message("a2", parent: "r1", #"{"role":"assistant","content":["#
                + #"{"type":"toolCall","id":"t2","name":"read","arguments":{"path":"/tmp/Package.swift"}},"#
                + #"{"type":"toolCall","id":"t3","arguments":{}}],"stopReason":"toolUse","timestamp":3}"#),
            Self.toolResult("r2", parent: "a2", toolCallID: "t2"),
            Self.toolResult("r3", parent: "r2", toolCallID: "t3"),
            Self.assistant("a3", parent: "r3", "Fixed."),
            Self.entry("label", "l1", parent: "a3", #""targetId":"u1","label":"start""#),
            Self.entry("session_info", "n1", parent: "l1", #""name":"Build fix""#),
            Self.entry("custom", "c1", parent: "n1", #""customType":"my-extension","data":{"count":1}"#),
        ])

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Fix the build"),
            .assistantMessage("Looking at it."),
            .toolCalls(["bash · swift build", "read · /tmp/Package.swift", "tool"]),
            .assistantMessage("Fixed."),
        ])
        #expect(transcript.entries.map(\.startsTurn) == [true, true, false, false])
        #expect(transcript.entries.first?.timestamp == ISO8601TimestampParser.shared.date(from: Self.timestamp))
    }

    @Test func showsOnlyTheBranchTheLastEntryIsOn() throws {
        let transcript = try read([
            Self.user("u1", parent: nil, "Start"),
            Self.assistant("a1", parent: "u1", "Started."),
            Self.user("u2", parent: "a1", "Try approach A"),
            Self.assistant("a2", parent: "u2", "Approach A is done."),
            Self.user("u3", parent: "a1", "Try approach B"),
            Self.assistant("a3", parent: "u3", "Approach B is done."),
        ])

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Start"),
            .assistantMessage("Started."),
            .userMessage("Try approach B"),
            .assistantMessage("Approach B is done."),
        ])
    }

    @Test func marksCompactionsAndBranchSummariesWhereTheyHappened() throws {
        let transcript = try read([
            Self.user("u1", parent: nil, "Start"),
            Self.assistant("a1", parent: "u1", "Started."),
            Self.user("u2", parent: "a1", "Abandoned idea"),
            Self.assistant("a2", parent: "u2", "Abandoned reply"),
            Self.entry("branch_summary", "b1", parent: "a1", #""fromId":"a2","summary":"Tried an idea that did not work""#),
            Self.user("u3", parent: "b1", "Another idea"),
            Self.assistant("a3", parent: "u3", "Done."),
            Self.entry("compaction", "c1", parent: "a3", #""summary":"Hidden summary","firstKeptEntryId":"u3","tokensBefore":50000"#),
            Self.user("u4", parent: "c1", "Next"),
        ])

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Start"),
            .assistantMessage("Started."),
            .note(PiTranscriptReader.branchSummaryNoteText),
            .userMessage("Another idea"),
            .assistantMessage("Done."),
            .note(TranscriptBuilder.compactionNoteText),
            .userMessage("Next"),
        ])
    }

    @Test func showsWhatTheUserTypedWhetherContentIsTextOrParts() throws {
        let skillBlock = #"<skill name=\"review\" location=\"/skills/review/SKILL.md\">\nReferences are relative to /skills/review.\n\nHidden instructions\n</skill>\n\nthe login page"#
        let transcript = try read([
            Self.user("u1", parent: nil, "Plain text"),
            Self.message("u2", parent: "u1", #"{"role":"user","content":[{"type":"text","text":"Look at this"},"#
                + #"{"type":"image","data":"AAAA","mimeType":"image/png"},{"type":"text","text":"and this"}],"timestamp":1}"#),
            Self.user("u3", parent: "u2", skillBlock),
            Self.message("x1", parent: "u3", #"{"role":"bashExecution","command":"git status","output":"hidden","exitCode":0,"cancelled":false,"truncated":false,"timestamp":1}"#),
            Self.message("x2", parent: "x1", #"{"role":"bashExecution","command":"ls","output":"hidden","exitCode":0,"cancelled":false,"truncated":false,"excludeFromContext":true,"timestamp":1}"#),
            Self.entry("custom_message", "m1", parent: "x2", #""customType":"intercom_message","content":"Hidden extension message","display":true"#),
            Self.entry("custom_message", "m2", parent: "m1", #""customType":"subagent-notify","content":"Hidden","display":false"#),
        ])

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Plain text"),
            .userMessage("Look at this\n\n[Image]\n\nand this"),
            .userMessage("/skill:review the login page"),
            .userMessage("!git status"),
            .userMessage("!!ls"),
        ])
    }

    @Test func showsAFailedReplysErrorAsANote() throws {
        let transcript = try read([
            Self.user("u1", parent: nil, "Hello"),
            Self.message("a1", parent: "u1", #"{"role":"assistant","content":[],"stopReason":"error","errorMessage":"429 rate limited","timestamp":1}"#),
            Self.message("a2", parent: "a1", #"{"role":"assistant","content":[],"stopReason":"aborted","errorMessage":"Request was aborted","timestamp":1}"#),
        ])

        #expect(transcript.entries.map(\.content) == [.userMessage("Hello"), .note("429 rate limited")])
    }

    /// A field of an unexpected type reads as missing, as it would in a JSON dictionary, and the rest of the entry
    /// is still shown.
    @Test func fieldsOfAnotherTypeDoNotHideTheirEntry() throws {
        let transcript = try read([
            #"{"type":"message","id":"u1","parentId":null,"timestamp":17,"message":{"role":"user","content":"Untimed"}}"#,
            Self.message("x1", parent: "u1", #"{"role":"bashExecution","command":"ls","excludeFromContext":"yes","timestamp":1}"#),
            Self.message("a1", parent: "x1", #"{"role":"assistant","content":["#
                + #"{"type":"text","text":5},{"type":"text","text":"Still here."},"#
                + #"{"type":"toolCall","name":7,"arguments":"ls -la"},"#
                + #"{"type":"toolCall","name":"bash","arguments":{"timeout":60,"command":["git","status"],"env":null}}"#
                + #"],"stopReason":"error","errorMessage":{"code":500},"timestamp":2}"#),
            Self.message("a2", parent: "a1", #"{"role":"assistant","content":"Plain text is not an assistant's content","timestamp":3}"#),
        ])

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Untimed"),
            .userMessage("!ls"),
            .assistantMessage("Still here."),
            .toolCalls(["tool", "bash · git status"]),
        ])
        #expect(transcript.entries.first?.timestamp == nil)
    }

    /// Pi writes `excludeFromContext` as a boolean; the numbers 0 and 1 read as one too, as in a JSON dictionary.
    @Test func aShellCommandsExcludeFromContextReadsZeroAndOneAsABoolean() throws {
        let values = ["true", "1", "1.0", "0", "2", "false"]
        let lines = values.enumerated().map { offset, value in
            Self.message("x\(offset)", parent: offset == 0 ? nil : "x\(offset - 1)",
                         #"{"role":"bashExecution","command":"c\#(offset)","excludeFromContext":\#(value),"timestamp":1}"#)
        }

        let transcript = try read(lines)

        #expect(transcript.entries.map(\.content) == [
            .userMessage("!!c0"),
            .userMessage("!!c1"),
            .userMessage("!!c2"),
            .userMessage("!c3"),
            .userMessage("!c4"),
            .userMessage("!c5"),
        ])
    }

    @Test func linesInAnotherKeyOrderAreParsedAndLinked() throws {
        let reorderedUser = #"{"message":{"content":"Reordered","role":"user"},"parentId":"a1","id":"u2","timestamp":"2026-09-30T10:00:00.000Z","type":"message"}"#
        let escapedID = #"{"type":"message","id":"a\u0032","parentId":"u2","timestamp":"2026-09-30T10:00:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Escaped id"}]}}"#
        let transcript = try read([
            Self.user("u1", parent: nil, "Start"),
            Self.assistant("a1", parent: "u1", "Started."),
            reorderedUser,
            escapedID,
            Self.assistant("a3", parent: "a2", "Linked through the escaped id."),
        ])

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Start"),
            .assistantMessage("Started."),
            .userMessage("Reordered"),
            .assistantMessage("Escaped id"),
            .assistantMessage("Linked through the escaped id."),
        ])
    }

    @Test func skipsMalformedLinesAndALastLineStillBeingWritten() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let completeLines = [
            "not json",
            Self.header,
            Self.user("u1", parent: nil, "Start"),
            #"{"type":"message","id":"broken""#,
            "[1,2,3]",
            Self.assistant("a1", parent: "u1", "Started."),
            #"{"type":"message","message":{"role":"user","content":"No id"}}"#,
            Self.user("u2", parent: "a1", "Next"),
        ]
        // Pi writes each line in one append; until it finishes, the file ends partway into the line.
        let partialLastLine = Self.user("u3", parent: "u2", "Half written").dropLast(4)

        let transcript = try TranscriptFileReader.pi.read(
            SampleTranscriptLines.fileContents(completeLines) + Data(partialLastLine.utf8),
            in: directory
        )

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Start"),
            .assistantMessage("Started."),
            .userMessage("Next"),
        ])
    }

    @Test func aMissingOrLoopingParentEndsTheConversation() throws {
        let missingParent = try read([
            Self.user("u1", parent: nil, "Unreachable"),
            Self.user("u2", parent: "gone", "After a missing parent"),
            Self.assistant("a2", parent: "u2", "Reply"),
        ])
        let loop = try read([
            Self.user("u1", parent: "a1", "Loop start"),
            Self.assistant("a1", parent: "u1", "Loop end"),
        ])

        #expect(missingParent.entries.map(\.content) == [.userMessage("After a missing parent"), .assistantMessage("Reply")])
        #expect(loop.entries.map(\.content) == [.userMessage("Loop start"), .assistantMessage("Loop end")])
    }

    @Test func headerOnlyAndEmptyFilesShowNothing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let headerOnly = try PiSessionFolderFixture(sessionsDirectory: directory).writeSession(
            id: UUID().uuidString.lowercased(),
            projectPath: "/Users/me/app"
        )
        let empty = directory.appendingPathComponent("empty.jsonl")
        try Data().write(to: empty)

        #expect(try PiTranscriptReader().read(headerOnly) == TranscriptContent(entries: [], omittedEntryCount: 0))
        #expect(try PiTranscriptReader().read(empty) == TranscriptContent(entries: [], omittedEntryCount: 0))
    }

    @Test func versionOneSessionsWithoutLinksAreShownInFileOrder() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let lines = [
            #"{"type":"session","id":"019a0000-0000-7000-8000-000000000000","timestamp":"2026-09-30T10:00:00.000Z","cwd":"/tmp"}"#,
            #"{"type":"message","timestamp":"2026-09-30T10:00:01.000Z","message":{"role":"user","content":"First","timestamp":1}}"#,
            #"{"type":"message","timestamp":"2026-09-30T10:00:02.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Reply"},{"type":"toolCall","id":"t1","name":"bash","arguments":{"command":"ls"}}],"timestamp":2}}"#,
            #"{"type":"message","timestamp":"2026-09-30T10:00:03.000Z","message":{"role":"toolResult","toolCallId":"t1","toolName":"bash","content":[],"isError":false,"timestamp":3}}"#,
            #"{"type":"compaction","timestamp":"2026-09-30T10:00:04.000Z","summary":"Hidden","firstKeptEntryIndex":1,"tokensBefore":10}"#,
            #"{"type":"message","timestamp":"2026-09-30T10:00:05.000Z","message":{"role":"hookMessage","content":"Hidden","display":true,"timestamp":5}}"#,
            #"{"type":"message","timestamp":"2026-09-30T10:00:06.000Z","message":{"role":"user","content":"Second","timestamp":6}}"#,
        ]

        let transcript = try TranscriptFileReader.pi.read(SampleTranscriptLines.fileContents(lines), in: directory)

        #expect(transcript.entries.map(\.content) == [
            .userMessage("First"),
            .assistantMessage("Reply"),
            .toolCalls(["bash · ls"]),
            .note(TranscriptBuilder.compactionNoteText),
            .userMessage("Second"),
        ])
    }

    @Test func loaderRoutesPiSessionsToThisReader() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = try PiSessionFolderFixture(sessionsDirectory: directory).writeSession(
            id: UUID().uuidString.lowercased(),
            projectPath: "/Users/me/app",
            lines: [Self.user("u1", parent: nil, "Hello Pi")]
        )

        let transcript = try await TranscriptLoader.load(.fixture(provider: .pi, sourceFile: file))

        #expect(transcript.entries.map(\.content) == [.userMessage("Hello Pi")])
    }

    // MARK: - Session lines in Pi's own key order

    private static let timestamp = "2026-09-30T10:00:00.000Z"
    private static let header = #"{"type":"session","version":3,"id":"019a0000-0000-7000-8000-000000000000","timestamp":"2026-09-30T10:00:00.000Z","cwd":"/tmp"}"#

    /// Writes the lines after a session header and reads them as the preview does.
    private func read(_ lines: [String]) throws -> TranscriptContent {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = try PiSessionFolderFixture(sessionsDirectory: directory).writeSession(
            id: UUID().uuidString.lowercased(),
            projectPath: "/Users/me/app",
            lines: lines
        )
        return try PiTranscriptReader().read(file)
    }

    private static func entry(_ type: String, _ id: String, parent: String?, _ fields: String) -> String {
        let parentJSON = parent.map { "\"\($0)\"" } ?? "null"
        return #"{"type":"\#(type)","id":"\#(id)","parentId":\#(parentJSON),"timestamp":"\#(timestamp)",\#(fields)}"#
    }

    private static func message(_ id: String, parent: String?, _ messageJSON: String) -> String {
        entry("message", id, parent: parent, #""message":\#(messageJSON)"#)
    }

    private static func user(_ id: String, parent: String?, _ text: String) -> String {
        message(id, parent: parent, #"{"role":"user","content":"\#(text)","timestamp":1}"#)
    }

    private static func assistant(_ id: String, parent: String?, _ text: String) -> String {
        message(id, parent: parent, #"{"role":"assistant","content":[{"type":"text","text":"\#(text)"}],"stopReason":"stop","timestamp":2}"#)
    }

    private static func toolResult(_ id: String, parent: String?, toolCallID: String) -> String {
        message(id, parent: parent, #"{"role":"toolResult","toolCallId":"\#(toolCallID)","toolName":"bash","#
            + #""content":[{"type":"text","text":"hidden output"}],"isError":false,"timestamp":3}"#)
    }
}
