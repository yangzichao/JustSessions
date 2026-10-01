import Testing
@testable import JustSessions

struct ConversationProviderFilterTests {
    @Test func offersAllToolsThenTheOfferedToolsInTheirUsualOrder() {
        let choices = ConversationProviderFilter.choices(offering: [.pi, .claude], selected: .all)
        #expect(choices == [.all, .only(.claude), .only(.pi)])
        #expect(choices.map(\.title) == ["All tools", "Claude Code", "Pi"])
    }

    @Test func selectedToolStaysListedAfterItIsNoLongerOffered() {
        #expect(ConversationProviderFilter.choices(offering: [.claude], selected: .only(.kiro)) == [.all, .only(.claude), .only(.kiro)])
    }

    @Test func filterKeepsItsToolOrEveryTool() {
        #expect(ConversationProviderFilter.only(.opencode).includes(.opencode))
        #expect(!ConversationProviderFilter.only(.opencode).includes(.codex))
        #expect(ConversationProviderFilter.all.includes(.kiro))
    }
}
