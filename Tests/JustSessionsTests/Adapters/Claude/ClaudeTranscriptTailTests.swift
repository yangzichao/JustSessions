import Foundation
import Testing

@testable import JustSessions

struct ClaudeTranscriptTailTests {
    @Test func readsTheLastTimestampAndTheLastCustomTitle() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"custom-title","customTitle":"First name","timestamp":"2026-09-24T10:00:00Z"}"#,
                #"{"type":"custom-title","customTitle":"Second name"}"#,
                #"{"type":"user","timestamp":"2026-09-24T11:00:00Z","message":{"content":"Keep going"}}"#,
                #"{"type":"summary","summary":"No timestamp here"}"#,
                "not json",
            ]))

        #expect(tail.latestTimestamp == ConversationMetadata.date("2026-09-24T11:00:00Z"))
        #expect(tail.latestCustomTitle == "Second name")
    }

    @Test func readsTheModelOfTheLastAssistantLineThatNamesOne() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"assistant","message":{"model":"claude-haiku-4-5-20251001","content":"Earlier"}}"#,
                #"{"type":"assistant","message":{"model":"claude-opus-4-8","content":"Later"}}"#,
                #"{"type":"assistant","message":{"model":"<synthetic>","content":"Interrupted"}}"#,
                #"{"type":"user","timestamp":"2026-09-24T11:00:00Z","message":{"content":"Keep going"}}"#,
                #"{"type":"custom-title","customTitle":"Named"}"#,
            ]))

        #expect(tail.latestModel == "claude-opus-4-8")
        #expect(tail.latestCustomTitle == "Named")
        #expect(tail.latestTimestamp == ConversationMetadata.date("2026-09-24T11:00:00Z"))
    }

    @Test func readsTheLastGeneratedTitle() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"ai-title","aiTitle":"Early guess","sessionId":"s"}"#,
                #"{"type":"user","timestamp":"2026-09-24T11:00:00Z","message":{"content":"Keep going"}}"#,
                #"{"type":"ai-title","aiTitle":"Build fixes","sessionId":"s"}"#,
                #"{"type":"custom-title","customTitle":"Named"}"#,
            ]))

        #expect(tail.latestAITitle == "Build fixes")
        #expect(tail.latestCustomTitle == "Named")
    }

    @Test func aTranscriptWithNeitherSaysNothing() {
        let tail = ClaudeTranscriptTail(lines: jsonLines([#"{"type":"user","message":{"content":"Hi"}}"#]))

        #expect(tail.latestTimestamp == nil)
        #expect(tail.latestCustomTitle == nil)
        #expect(tail.latestAITitle == nil)
        #expect(tail.relocatedWorkingDirectory == nil)
        #expect(tail.movedProjectDirectory == nil)
        #expect(tail.latestModel == nil)
    }

    /// Claude Code 2.1.296 writes a `relocated` line when `/cd` moves a session, and again with the session's other
    /// metadata. The last one names the folder the session is in now.
    @Test func readsTheFolderOfTheLastRelocatedLine() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/first-move"}"#,
                #"{"type":"user","cwd":"/Users/me/first-move","timestamp":"2026-10-13T10:00:00Z","message":{"content":"Keep going"}}"#,
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/second-move"}"#,
                #"{"type":"user","cwd":"/Users/me/second-move/web","timestamp":"2026-10-13T11:00:00Z","message":{"content":"Build it"}}"#,
            ]))

        #expect(tail.relocatedWorkingDirectory == "/Users/me/second-move")
    }

    @Test func aRelocatedLineOlderThanTheTimestampAndTitleIsStillRead() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/other"}"#,
                #"{"type":"user","cwd":"/Users/me/other","timestamp":"2026-10-13T10:00:00Z","message":{"content":"Keep going"}}"#,
                #"{"type":"custom-title","customTitle":"Moved session"}"#,
                #"{"type":"assistant","timestamp":"2026-10-13T10:01:00Z","message":{"content":"Done"}}"#,
            ]))

        #expect(tail.latestTimestamp == ConversationMetadata.date("2026-10-13T10:01:00Z"))
        #expect(tail.latestCustomTitle == "Moved session")
        #expect(tail.relocatedWorkingDirectory == "/Users/me/other")
    }

    /// Entering a worktree writes a `relocated` line with the worktree's folder and a `worktree-state` line that names
    /// the folder the session entered it from. Claude Code's `/resume` lists the session in that folder.
    @Test func aSessionInAWorktreeBelongsToTheRepositoryItEnteredItFrom() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/app/.claude/worktrees/fix"}"#,
                #"{"type":"worktree-state","worktreeSession":{"originalCwd":"/Users/me/app","worktreePath":"/Users/me/app/.claude/worktrees/fix","worktreeName":"fix"},"sessionId":"s1"}"#,
                #"{"type":"user","cwd":"/Users/me/app/.claude/worktrees/fix","timestamp":"2026-10-15T10:00:00Z","message":{"content":"Keep going"}}"#,
            ]))

        #expect(tail.worktreeDirectory == "/Users/me/app/.claude/worktrees/fix")
        #expect(tail.movedProjectDirectory == "/Users/me/app")
    }

    /// Leaving a worktree writes a `worktree-state` line with no `worktreeSession`, and a `relocated` line with the
    /// folder the session went back to.
    @Test func aSessionThatLeftItsWorktreeIsInTheFolderItWentBackTo() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/app/.claude/worktrees/fix"}"#,
                #"{"type":"worktree-state","worktreeSession":{"originalCwd":"/Users/me/app","worktreePath":"/Users/me/app/.claude/worktrees/fix"},"sessionId":"s1"}"#,
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/other"}"#,
                #"{"type":"worktree-state","worktreeSession":null,"sessionId":"s1"}"#,
            ]))

        #expect(tail.movedProjectDirectory == "/Users/me/other")
    }

    /// Resuming a session whose worktree was removed writes a `worktree-state` line with no `worktreeSession` and no
    /// `relocated` line: the last one still names the worktree, and the session runs in the repository.
    @Test func aSessionResumedAfterItsWorktreeWasRemovedStaysWithTheRepository() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/app/.claude/worktrees/fix"}"#,
                #"{"type":"worktree-state","worktreeSession":{"originalCwd":"/Users/me/app","worktreePath":"/Users/me/app/.claude/worktrees/fix"},"sessionId":"s1"}"#,
                #"{"type":"assistant","timestamp":"2026-10-15T10:01:00Z","message":{"content":"Done"}}"#,
                #"{"type":"worktree-state","worktreeSession":null,"sessionId":"s1"}"#,
            ]))

        #expect(tail.movedProjectDirectory == "/Users/me/app")
    }

    @Test func aSessionMovedWithCdOutOfItsWorktreeIsInTheFolderItMovedTo() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/app/.claude/worktrees/fix"}"#,
                #"{"type":"worktree-state","worktreeSession":{"originalCwd":"/Users/me/app","worktreePath":"/Users/me/app/.claude/worktrees/fix"},"sessionId":"s1"}"#,
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/other"}"#,
            ]))

        #expect(tail.movedProjectDirectory == "/Users/me/other")
    }

    @Test func aWorktreeStateLineOlderThanTheTimestampTitleAndModelIsStillRead() {
        let tail = ClaudeTranscriptTail(
            lines: jsonLines([
                #"{"type":"worktree-state","worktreeSession":{"originalCwd":"/Users/me/app","worktreePath":"/Users/me/app/.claude/worktrees/fix"},"sessionId":"s1"}"#,
                #"{"type":"relocated","sessionId":"s1","relocatedCwd":"/Users/me/app/.claude/worktrees/fix"}"#,
                #"{"type":"custom-title","customTitle":"Worktree session"}"#,
                #"{"type":"assistant","timestamp":"2026-10-15T10:01:00Z","message":{"model":"claude-opus-4-7","content":"Done"}}"#,
            ]))

        #expect(tail.latestCustomTitle == "Worktree session")
        #expect(tail.movedProjectDirectory == "/Users/me/app")
    }

    @Test func onlyTheEndOfALongTranscriptIsRead() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("\(UUID().uuidString).jsonl")
        let filler = String(repeating: #"{"type":"assistant"}"# + "\n", count: 13_000)
        #expect(filler.utf8.count > ClaudeTranscriptTail.maximumByteCount)
        let earlyTitle = #"{"type":"custom-title","customTitle":"Early name"}"# + "\n"
        let lastLine = #"{"type":"user","timestamp":"2026-09-24T11:00:00Z"}"# + "\n"
        try (earlyTitle + filler + lastLine).write(to: file, atomically: true, encoding: .utf8)

        let tail = ClaudeTranscriptTail(file: file)
        #expect(tail.latestCustomTitle == nil)
        #expect(tail.latestTimestamp == ConversationMetadata.date("2026-09-24T11:00:00Z"))
    }
}
