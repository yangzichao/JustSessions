import Foundation
import Testing
@testable import JustSessions

struct CodexTranscriptReaderTests {
    @Test func keepsUserAndAssistantMessagesAndSkipsInjectedContext() throws {
        let file = try TranscriptTestFiles.write([
            ["timestamp": "2026-09-24T10:00:00.000Z", "type": "session_meta", "payload": ["id": "abc", "cwd": "/tmp"]],
            codexItem(["type": "message", "role": "developer", "content": [["type": "input_text", "text": "hidden"]]]),
            codexItem(["type": "message", "role": "user", "content": [
                ["type": "input_text", "text": "# AGENTS.md instructions"],
                ["type": "input_text", "text": "<environment_context>hidden</environment_context>"],
            ]]),
            codexItem(["type": "message", "role": "user", "content": [
                ["type": "input_text", "text": "Add a test"],
                ["type": "input_image", "image_url": "data:"],
            ]]),
            codexItem(["type": "reasoning", "summary": []]),
            codexItem(["type": "function_call", "name": "shell", "arguments": #"{"command":["bash","-lc","swift test"]}"#]),
            codexItem(["type": "function_call_output", "output": "hidden"]),
            codexItem(["type": "custom_tool_call", "name": "exec", "input": "\nconst x = 1\nmore"]),
            ["timestamp": "2026-09-24T10:00:02.000Z", "type": "event_msg", "payload": ["type": "agent_message", "message": "duplicate"]],
            codexItem(["type": "message", "role": "assistant", "content": [["type": "output_text", "text": "Done."]]]),
            ["timestamp": "2026-09-24T10:00:03.000Z", "type": "compacted", "payload": ["message": ""]],
        ])
        defer { try? FileManager.default.removeItem(at: file) }

        let transcript = try CodexTranscriptReader().read(file)

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Add a test\n\n[Image]"),
            .toolCalls(["shell · bash -lc swift test", "exec · const x = 1"]),
            .assistantMessage("Done."),
            .note("Earlier messages were compacted"),
        ])
    }

    @Test func lineCheckSkipsEventsAndToolOutputsWithoutParsing() {
        func line(_ text: String) -> Data { Data(text.utf8) }

        #expect(!CodexTranscriptReader.mightContainTranscriptItem(line(#"{"timestamp":"t","ordinal":1,"type":"event_msg","payload":{"type":"item_completed"}}"#)))
        #expect(!CodexTranscriptReader.mightContainTranscriptItem(line(#"{"timestamp":"t","type":"response_item","payload":{"type":"function_call_output"}}"#)))
        #expect(CodexTranscriptReader.mightContainTranscriptItem(line(#"{"timestamp":"t","type":"response_item","payload":{"type":"function_call","name":"shell"}}"#)))
        #expect(CodexTranscriptReader.mightContainTranscriptItem(line(#"{"timestamp":"t","type":"response_item","payload":{"type":"message"}}"#)))
        // Lines in an unexpected shape are parsed rather than skipped.
        #expect(CodexTranscriptReader.mightContainTranscriptItem(line(#"{"type":"event_msg","timestamp":"t"}"#)))
    }

    private func codexItem(_ payload: [String: Any]) -> [String: Any] {
        ["timestamp": "2026-09-24T10:00:01.000Z", "type": "response_item", "payload": payload]
    }
}
