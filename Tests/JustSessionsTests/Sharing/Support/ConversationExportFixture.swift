import Foundation
@testable import JustSessions

enum ConversationExportFixture {
    static let longMessage = String(repeating: "完整对话🙂", count: 3_000) + "\n```swift\nprint(\"Done\")\n```"
    static let entryCount = 2_002

    static func conversation(provider: ConversationProvider, in directory: URL) throws -> Conversation {
        if provider == .antigravity {
            let fixture = try AntigravitySessionFixture(configurationDirectory: directory)
            for index in 1..<entryCount {
                try fixture.appendPrompt(message(at: index), index: index)
            }
            return fixture.conversation
        }
        if provider == .opencode {
            let database = try OpenCodeDatabaseFixture(file: directory.appendingPathComponent("opencode.db"))
            try database.addSession("ses_exportfixture1")
            try database.addUserPrompts((0..<entryCount).map(message(at:)), session: "ses_exportfixture1")
            return .fixture(provider: .opencode, sessionID: "ses_exportfixture1", sourceFile: database.file)
        }
        var records: [[String: Any]] = []
        for index in 0..<entryCount {
            let text = message(at: index)
            switch provider {
            case .claude:
                records.append(["type": "user", "message": ["content": text]])
            case .codex:
                records.append(["type": "response_item", "payload": ["type": "message", "role": "user", "content": [["type": "input_text", "text": text]]]])
            case .kiro:
                records.append(["kind": "Prompt", "data": ["content": [["kind": "text", "data": text]]]])
            case .pi:
                records.append(["type": "message", "id": "entry-\(index)", "parentId": index == 0 ? NSNull() : "entry-\(index - 1)", "message": ["role": "user", "content": text]])
            case .antigravity, .opencode:
                preconditionFailure("Antigravity and OpenCode sessions are databases, made above")
            }
        }
        let temporaryFile = try TranscriptTestFiles.write(records)
        let file = directory.appendingPathComponent("session.jsonl")
        try FileManager.default.moveItem(at: temporaryFile, to: file)
        return .fixture(provider: provider, sourceFile: file)
    }

    private static func message(at index: Int) -> String {
        index == entryCount - 1 ? longMessage : "Message \(index)"
    }
}
