import Testing
@testable import JustSessions

struct TmuxSessionNameTests {
    @Test func readsTheSessionBackFromItsOwnName() {
        for provider in ConversationProvider.allCases {
            let sessionID = provider == .opencode ? "ses_3a9f0c2be1ffe9TNd6Ab7kQ2xM" : "01a0cf02-2025-7990-8bb2-80feff2349d4"
            let session = TmuxSessionName.session(named: TmuxSessionName.forSession(provider: provider, sessionID: sessionID))

            #expect(session?.provider == provider)
            #expect(session?.sessionID == sessionID)
        }
    }

    @Test func otherNamesNameNoSession() {
        #expect(TmuxSessionName.session(named: TmuxSessionName.unique(for: .codex)) == nil)
        #expect(TmuxSessionName.session(named: "justsessions-codex-") == nil)
        #expect(TmuxSessionName.session(named: "justsessions-gemini-01a0cf02-2025-7990-8bb2-80feff2349d4") == nil)
        #expect(TmuxSessionName.session(named: "work") == nil)
        #expect(TmuxSessionName.session(named: "justsessions-opencode-01a0cf02-2025-7990-8bb2-80feff2349d4") == nil)
        #expect(TmuxSessionName.session(named: "justsessions-claude-ses_3a9f0c2be1ffe9TNd6Ab7kQ2xM") == nil)
    }
}
