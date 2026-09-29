import Foundation
import Testing
@testable import JustSessions

struct CodexFirstUserPromptTests {
    @Test func skipsWhatCodexAddsBeforeTheUsersFirstPrompt() throws {
        let lines = try [
            jsonLines([#"{"type":"session_meta","payload":{"id":"abc","cwd":"/Users/me/app"}}"#]),
            [
                responseItemLine(role: "developer", parts: [["type": "input_text", "text": "Developer notes"]]),
                responseItemLine(role: "user", parts: [["type": "input_text", "text": "# AGENTS.md instructions for /Users/me/app"]]),
                responseItemLine(role: "user", parts: [
                    ["type": "input_image", "image_url": "data:image/png;base64,"],
                    ["type": "input_text", "text": "  \n"],
                    ["type": "input_text", "text": "  Refactor the parser\n"],
                ]),
            ],
        ].flatMap { $0 }

        #expect(CodexFirstUserPrompt.find(amongLines: lines) == "Refactor the parser")
    }

    @Test(arguments: CodexFirstUserPrompt.injectedContextPrefixes)
    func eachKindOfInjectedContextIsSkipped(_ prefix: String) throws {
        let line = try responseItemLine(role: "user", parts: [["type": "input_text", "text": "\(prefix)\nmore context"]])

        #expect(CodexFirstUserPrompt.find(amongLines: [line]) == nil)
    }

    @Test func messagesFromAnyoneButTheUserAreSkipped() throws {
        let line = try responseItemLine(role: "assistant", parts: [["type": "output_text", "text": "Assistant reply"]])

        #expect(CodexFirstUserPrompt.find(amongLines: [line]) == nil)
    }

    @Test func linesPastTheLineLimitAreNotRead() throws {
        let filler = jsonLines(Array(repeating: #"{"type":"event_msg"}"#, count: CodexFirstUserPrompt.maximumLineCount - 1))
        let prompt = try responseItemLine(role: "user", parts: [["type": "input_text", "text": "Add a test"]])

        #expect(CodexFirstUserPrompt.find(amongLines: filler + [prompt]) == "Add a test")
        #expect(CodexFirstUserPrompt.find(amongLines: filler + jsonLines([#"{"type":"event_msg"}"#]) + [prompt]) == nil)
    }

    private func responseItemLine(role: String, parts: [[String: String]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "type": "response_item",
            "payload": ["type": "message", "role": role, "content": parts] as [String: Any],
        ])
    }
}
