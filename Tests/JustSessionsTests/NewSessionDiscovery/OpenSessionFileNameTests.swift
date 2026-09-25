import Foundation
import Testing
@testable import JustSessions

struct OpenSessionFileNameTests {
    private static let sessionID = "01a0d4f4-8a4e-78e0-ae33-e6eb845cd561"

    @Test func readsTheCodexSessionIDFromItsRolloutFileName() {
        let rollout = "/Users/example/.codex/sessions/2026/09/24/rollout-2026-09-24T12-46-31-\(Self.sessionID).jsonl"

        #expect(OpenSessionFileName.sessionID(inOpenFilePath: rollout, provider: .codex) == Self.sessionID)
        #expect(OpenSessionFileName.sessionID(inOpenFilePath: "/Users/example/.codex/log/codex-tui.log", provider: .codex) == nil)
        #expect(OpenSessionFileName.sessionID(inOpenFilePath: "/Users/example/.codex/sessions/rollout-broken.jsonl", provider: .codex) == nil)
    }

    @Test func readsTheAntigravitySessionIDFromItsDatabaseOrCompanionFiles() {
        let conversations = "/Users/example/.gemini/antigravity-cli/conversations"

        for fileName in ["\(Self.sessionID).db", "\(Self.sessionID).db-wal", "\(Self.sessionID).db-shm"] {
            #expect(OpenSessionFileName.sessionID(inOpenFilePath: "\(conversations)/\(fileName)", provider: .antigravity)
                == Self.sessionID)
        }
        #expect(OpenSessionFileName.sessionID(
            inOpenFilePath: "/Users/example/.gemini/antigravity-cli/conversation_summaries.db",
            provider: .antigravity
        ) == nil)
        #expect(OpenSessionFileName.sessionID(
            inOpenFilePath: "/Users/example/Library/Caches/\(Self.sessionID).db",
            provider: .antigravity
        ) == nil)
    }

    @Test func claudeTabsAreNotMatchedByOpenFiles() {
        let transcript = "/Users/example/.claude/projects/-Users-example-project/\(Self.sessionID).jsonl"

        #expect(OpenSessionFileName.sessionID(inOpenFilePath: transcript, provider: .claude) == nil)
    }
}
