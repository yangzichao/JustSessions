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
}
