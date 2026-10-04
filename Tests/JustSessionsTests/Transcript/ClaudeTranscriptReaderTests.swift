import Foundation
import Testing
@testable import JustSessions

struct ClaudeTranscriptReaderTests {
    @Test func keepsVisibleMessagesAndMergesToolCalls() throws {
        let file = try TranscriptTestFiles.write([
            ["type": "user", "timestamp": "2026-09-24T10:00:00.000Z", "message": ["role": "user", "content": "Fix the build"]],
            ["type": "user", "isMeta": true, "message": ["role": "user", "content": "<local-command-caveat>hidden</local-command-caveat>"]],
            ["type": "user", "message": ["role": "user", "content": "<local-command-stdout>hidden</local-command-stdout>"]],
            ["type": "assistant", "message": ["role": "assistant", "content": [
                ["type": "thinking", "thinking": "hidden"],
                ["type": "text", "text": "Looking at it."],
                ["type": "tool_use", "name": "Bash", "input": ["command": "swift build\nextra line", "description": "Build"]],
            ]]],
            ["type": "assistant", "message": ["role": "assistant", "content": [
                ["type": "tool_use", "name": "Read", "input": ["file_path": "/tmp/Package.swift"]],
            ]]],
            ["type": "user", "message": ["role": "user", "content": [["type": "tool_result", "content": "hidden output"]]]],
            ["type": "assistant", "isSidechain": true, "message": ["role": "assistant", "content": [["type": "text", "text": "hidden"]]]],
            ["type": "user", "isCompactSummary": true, "message": ["role": "user", "content": "hidden summary"]],
            ["type": "user", "message": ["role": "user", "content": "<command-name>/rename</command-name><command-args>Build fix</command-args>"]],
            ["type": "custom-title", "customTitle": "ignored"],
        ])
        defer { try? FileManager.default.removeItem(at: file) }

        let transcript = try ClaudeTranscriptReader().read(file)

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Fix the build"),
            .assistantMessage("Looking at it."),
            .toolCalls(["Bash · swift build", "Read · /tmp/Package.swift"]),
            .note("Earlier messages were compacted"),
            .userMessage("/rename Build fix"),
        ])
        #expect(transcript.entries.map(\.startsTurn) == [true, true, false, false, true])
        #expect(transcript.entries.first?.timestamp != nil)
    }

    /// A pasted image follows the user's text in their turn; a tool's screenshot follows the call that produced
    /// it in the assistant's turn.
    @Test func showsImagesFromUserMessagesAndToolResults() throws {
        let source: [String: Any] = ["type": "base64", "media_type": "image/png", "data": SampleTranscriptImage.base64]
        let file = try TranscriptTestFiles.write([
            ["type": "user", "message": ["role": "user", "content": [
                ["type": "text", "text": "What is in this?"],
                ["type": "image", "source": source],
            ]]],
            ["type": "assistant", "message": ["role": "assistant", "content": [
                ["type": "tool_use", "name": "Read", "input": ["file_path": "/tmp/diagram.png"]],
            ]]],
            ["type": "user", "message": ["role": "user", "content": [["type": "tool_result", "content": [
                ["type": "text", "text": "hidden caption"],
                ["type": "image", "source": source],
                ["type": "image", "source": ["type": "url", "url": "https://example.com/not-inline.png"]],
            ]]]]],
            ["type": "assistant", "message": ["role": "assistant", "content": "A diagram."]],
        ])
        defer { try? FileManager.default.removeItem(at: file) }

        let transcript = try ClaudeTranscriptReader().read(file)

        #expect(transcript.entries.map(\.content) == [
            .userMessage("What is in this?"),
            .userImage(SampleTranscriptImage.image),
            .toolCalls(["Read · /tmp/diagram.png"]),
            .toolResultImage(SampleTranscriptImage.image),
            .assistantMessage("A diagram."),
        ])
        #expect(transcript.entries.map(\.startsTurn) == [true, false, true, false, false])
    }
}
