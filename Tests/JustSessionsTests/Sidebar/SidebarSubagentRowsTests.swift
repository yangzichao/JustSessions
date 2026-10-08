import Foundation
import Testing
@testable import JustSessions

struct SidebarSubagentRowsTests {
    private let parent = Conversation.fixture(provider: .pi, sessionID: "parent")
    private let first = Conversation.fixture(provider: .pi, sessionID: "first", parentSessionID: "parent")
    private let second = Conversation.fixture(provider: .pi, sessionID: "second", parentSessionID: "parent")
    private let nested = Conversation.fixture(provider: .pi, sessionID: "nested", parentSessionID: "first")

    private func subagents(of conversation: Conversation) -> [Conversation] {
        [first, second, nested].filter { $0.parentID == conversation.id }
    }

    @Test func subagentsStayHiddenUntilTheirSessionIsExpanded() {
        var rows = SidebarSubagentRows()

        #expect(!rows.isExpanded(parent.id))
        #expect(rows.rows(under: parent, subagents: subagents(of:)).isEmpty)

        rows.toggle(parent.id)
        #expect(rows.rows(under: parent, subagents: subagents(of:)).map(\.id) == [first.id, second.id])
        #expect(rows.rows(under: parent, subagents: subagents(of:)).map(\.subagentCount) == [1, 0])

        rows.toggle(parent.id)
        #expect(rows.rows(under: parent, subagents: subagents(of:)).isEmpty)
    }

    @Test func aSubagentsOwnSubagentsShowOneLevelDeeperOnceItIsExpanded() {
        var rows = SidebarSubagentRows()
        rows.toggle(parent.id)
        rows.toggle(first.id)

        let shown = rows.rows(under: parent, subagents: subagents(of:))

        #expect(shown.map(\.id) == [first.id, nested.id, second.id])
        #expect(shown.map(\.depth) == [1, 2, 1])
    }

    @Test func aSessionNamedAsItsOwnAncestorShowsOnce() {
        let looping = Conversation.fixture(provider: .pi, sessionID: "parent", parentSessionID: "first")
        var rows = SidebarSubagentRows()
        rows.toggle(parent.id)
        rows.toggle(first.id)

        let shown = rows.rows(under: parent) { conversation in
            conversation.id == first.id ? [looping] : subagents(of: conversation)
        }

        #expect(shown.map(\.id) == [first.id, second.id])
    }
}
