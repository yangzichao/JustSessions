import Foundation
import Testing

@testable import JustSessions

@MainActor
struct DeletingWhenTabClosesTests {
    @Test func aNewSessionsTabPassesItsChoiceToTheSessionItLinksToInEveryWindow() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tab = openNewSessionTab(deletingSessionWhenClosed: true, in: sandbox)

        sandbox.first.link(tab, to: sandbox.conversation)

        #expect(sandbox.first.deletesSessionWhenClosed(tab))
        let otherWindowsChoice = sandbox.second.sessionsDeletedWhenTabCloses
        #expect(otherWindowsChoice.isDeletedWhenTabCloses(conversationID: sandbox.conversation.id))
    }

    @Test func aNewSessionsTabStartedWithoutTheChoiceKeepsItsSession() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tab = openNewSessionTab(deletingSessionWhenClosed: false, in: sandbox)

        sandbox.first.link(tab, to: sandbox.conversation)

        #expect(!sandbox.first.deletesSessionWhenClosed(tab))
        #expect(sandbox.first.sessionsDeletedWhenTabCloses.conversationIDs.isEmpty)
    }

    @Test func closingTheTabDeletesItsSessionWithoutAskingAndForgetsTheChoice() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.first
        let conversation = sandbox.conversation
        let tab = openNewSessionTab(deletingSessionWhenClosed: true, in: sandbox)
        store.link(tab, to: conversation)

        store.closeTabDeletingItsSession(tab.id)

        #expect(store.terminalSessions.isEmpty)
        try await expectEventually { !store.conversations.contains { $0.id == conversation.id } }
        #expect(store.alert == nil)
        #expect(store.sessionsDeletedWhenTabCloses.conversationIDs.isEmpty)
    }

    @Test func aTabNotLinkedYetClosesWithNothingDeleted() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.first
        let tab = openNewSessionTab(deletingSessionWhenClosed: true, in: sandbox)
        #expect(store.deletesSessionWhenClosed(tab))

        store.closeTabDeletingItsSession(tab.id)

        #expect(store.terminalSessions.isEmpty)
        #expect(store.conversations.map(\.id) == [sandbox.conversation.id])
    }

    @Test func keepSessionTakesTheChoiceBack() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.first
        let tab = openNewSessionTab(deletingSessionWhenClosed: true, in: sandbox)
        store.link(tab, to: sandbox.conversation)

        store.keepSessionAfterClosing(tab)

        #expect(!store.deletesSessionWhenClosed(tab))
        #expect(sandbox.second.sessionsDeletedWhenTabCloses.conversationIDs.isEmpty)
    }

    @Test func keepSessionBeforeTheTabIsLinkedKeepsTheSessionItLinksTo() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.first
        let tab = openNewSessionTab(deletingSessionWhenClosed: true, in: sandbox)

        store.keepSessionAfterClosing(tab)
        store.link(tab, to: sandbox.conversation)

        #expect(!store.deletesSessionWhenClosed(tab))
        #expect(store.sessionsDeletedWhenTabCloses.conversationIDs.isEmpty)
    }

    @Test func aTabThatFollowsItsCLIToAnotherSessionKeepsBoth() throws {
        let sandbox = try TwoWindowSandbox(sessionCount: 2)
        defer { sandbox.tearDown() }
        let store = sandbox.first
        let tab = openNewSessionTab(deletingSessionWhenClosed: true, in: sandbox)
        store.link(tab, to: sandbox.conversations[0])

        store.link(tab, to: sandbox.conversations[1])

        #expect(!store.deletesSessionWhenClosed(tab))
        #expect(store.sessionsDeletedWhenTabCloses.conversationIDs.isEmpty)
    }

    @Test func anotherTabOfTheSessionStillDeletesIt() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation
        sandbox.first.setDeletedWhenTabCloses(true, conversationIDs: [conversation.id])

        let tab = try #require(sandbox.openTab(of: conversation, in: sandbox.second))

        #expect(sandbox.second.deletesSessionWhenClosed(tab))
    }

    @Test func closingSeveralTabsAsksNothingForTheirsAndDeletesTheirSessions() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.first
        let conversation = sandbox.conversation
        let tab = openNewSessionTab(deletingSessionWhenClosed: false, in: sandbox)
        store.link(tab, to: conversation)
        let question = {
            store.closingQuestion(
                forTabs: [tab.id],
                tabCloseChoices: TabCloseChoicesByHost(),
                plainTerminalCloseChoice: .askEachTime
            )
        }
        #expect(question() != .closeWithoutAsking)

        store.setDeletedWhenTabCloses(true, conversationIDs: [conversation.id])
        #expect(question() == .closeWithoutAsking)
        store.closeTabs([tab.id], endingTmuxSessions: false)

        #expect(store.terminalSessions.isEmpty)
        try await expectEventually { !store.conversations.contains { $0.id == conversation.id } }
        #expect(store.alert == nil)
    }

    private func openNewSessionTab(deletingSessionWhenClosed: Bool, in sandbox: TwoWindowSandbox) -> TerminalSession {
        let tab = TerminalSession(
            engine: .swiftTerm,
            conversation: nil,
            provider: .claude,
            projectPath: sandbox.project.path,
            action: .new,
            displayTitle: "New session",
            command: NativeCLICommand(
                executablePath: "/usr/bin/true",
                arguments: [],
                workingDirectory: sandbox.project.path,
                environment: []
            )
        )
        tab.deletesSessionWhenClosed = deletingSessionWhenClosed
        sandbox.first.openTerminal(tab)
        return tab
    }
}
