import Foundation
import Testing
@testable import JustSessions

struct AppendedSessionNameSourceTests {
    private let codexDirectory = URL(fileURLWithPath: "/tmp/justsessions-tests/codex")

    @Test func claudeCodeAndPiNameTheSessionInItsOwnFileAndCodexInItsIndex() {
        let claudeSession = Conversation.fixture(provider: .claude)
        let piSession = Conversation.fixture(provider: .pi)

        #expect(AppendedSessionNameSource.file(for: claudeSession, codexDirectory: codexDirectory) == claudeSession.sourceFile)
        #expect(AppendedSessionNameSource.file(for: piSession, codexDirectory: codexDirectory) == piSession.sourceFile)
        #expect(
            AppendedSessionNameSource.file(for: .fixture(provider: .codex), codexDirectory: codexDirectory)
                == codexDirectory.appendingPathComponent("session_index.jsonl")
        )
        for provider in [ConversationProvider.antigravity, .kiro, .opencode] {
            #expect(AppendedSessionNameSource.file(for: .fixture(provider: provider), codexDirectory: codexDirectory) == nil)
        }
    }

    @Test func claudeCodeTakesTheLastCustomTitle() {
        let lines = jsonLines([
            #"{"type":"custom-title","customTitle":"first-name","sessionId":"s"}"#,
            #"{"type":"user","message":{"content":"mentions custom-title in passing"}}"#,
            #"{"type":"custom-title","customTitle":"second-name","sessionId":"s"}"#,
            #"{"type":"agent-name","agentName":"second-name","sessionId":"s"}"#,
        ])

        #expect(AppendedSessionNameSource.latestName(for: .fixture(provider: .claude), amongLines: lines) == "second-name")
    }

    @Test func piTakesTheLastSessionInfoName() {
        let lines = jsonLines([
            #"{"type":"session_info","name":"Pi name"}"#,
            #"{"type":"message","message":{"role":"user","content":"hello"}}"#,
        ])

        #expect(AppendedSessionNameSource.latestName(for: .fixture(provider: .pi), amongLines: lines) == "Pi name")
    }

    @Test func codexTakesTheLastNameOfTheTabsOwnThread() {
        let thread = Conversation.fixture(provider: .codex)
        let lines = jsonLines([
            #"{"id":"\#(thread.sessionID)","thread_name":"Old thread name","updated_at":"2026-10-05T00:00:00Z"}"#,
            #"{"id":"\#(thread.sessionID)","thread_name":"New thread name","updated_at":"2026-10-05T00:01:00Z"}"#,
            #"{"id":"another-thread","thread_name":"Someone else","updated_at":"2026-10-05T00:02:00Z"}"#,
        ])

        #expect(AppendedSessionNameSource.latestName(for: thread, amongLines: lines) == "New thread name")
        #expect(AppendedSessionNameSource.latestName(for: .fixture(provider: .codex), amongLines: lines) == nil)
    }

    @Test func linesThatNameNothingGiveNoName() {
        let lines = jsonLines([#"{"type":"assistant","message":{"content":"working"}}"#])

        #expect(AppendedSessionNameSource.latestName(for: .fixture(provider: .claude), amongLines: lines) == nil)
        #expect(AppendedSessionNameSource.latestName(for: .fixture(provider: .opencode), amongLines: lines) == nil)
    }
}
