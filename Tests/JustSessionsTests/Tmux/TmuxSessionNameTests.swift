import Testing
@testable import JustSessions

struct TmuxSessionNameTests {
    @Test func readsTheSessionBackFromItsOwnName() {
        let sessionID = "01a0cf02-2025-7990-8bb2-80feff2349d4"
        for provider in ConversationProvider.allCases {
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
    }
}
