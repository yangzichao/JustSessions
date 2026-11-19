import Foundation
import Testing

@testable import JustSessions

@MainActor
struct ReopeningClosedTabsTests {
    @Test func aClosedSessionTabResumesAtItsPlaceSelected() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let first = sandbox.conversation(title: "First")
        let middle = sandbox.conversation(title: "Middle")
        let last = sandbox.conversation(title: "Last")
        store.replaceConversations(on: .thisMac, with: [first, middle, last])
        for conversation in [first, middle, last] { store.launch(conversation, action: .resume) }
        let closedTab = try #require(store.runningTerminal(for: middle))

        store.closeTerminal(closedTab.id)
        #expect(store.canReopenClosedTab)
        store.reopenClosedTab()

        #expect(store.terminalSessions.map(\.displayTitle) == ["First", "Middle", "Last"])
        let reopenedTab = try #require(store.selectedTerminal)
        #expect(reopenedTab.id != closedTab.id)
        #expect(reopenedTab.conversation?.id == middle.id)
        #expect(reopenedTab.action == .resume)
        #expect(!reopenedTab.isWaitingToBeShown)
        #expect(!store.canReopenClosedTab)
    }

    @Test func eachTimeReopensTheTabClosedBeforeTheOneReopenedLast() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let conversation = sandbox.conversation()
        store.replaceConversations(on: .thisMac, with: [conversation])
        store.launch(conversation, action: .resume)
        store.openPlainTerminal(in: sandbox.projectLocation)
        let sessionTab = try #require(store.runningTerminal(for: conversation))
        let plainTerminal = try #require(store.terminalSessions.first { $0.isPlainTerminal })

        store.closeTerminal(plainTerminal.id)
        store.closeTerminal(sessionTab.id)
        store.reopenClosedTab()

        #expect(store.terminalSessions.map(\.displayTitle) == ["Session"])
        store.reopenClosedTab()

        #expect(store.terminalSessions.map(\.displayTitle) == ["Session", "Terminal · project"])
        let reopenedPlainTerminal = try #require(store.selectedTerminal)
        #expect(reopenedPlainTerminal.isPlainTerminal)
        #expect(reopenedPlainTerminal.projectDirectoryKey == sandbox.projectLocation.key)
        #expect(!store.canReopenClosedTab)
    }

    @Test func aSessionThatIsGoneIsPassedOverForTheTabClosedBeforeIt() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let gone = sandbox.conversation(title: "Gone")
        store.replaceConversations(on: .thisMac, with: [gone])
        store.openPlainTerminal(in: sandbox.projectLocation)
        store.launch(gone, action: .resume)
        let plainTerminal = try #require(store.terminalSessions.first { $0.isPlainTerminal })
        let goneTab = try #require(store.runningTerminal(for: gone))
        store.closeTerminal(plainTerminal.id)
        store.closeTerminal(goneTab.id)

        store.replaceConversations(on: .thisMac, with: [])
        store.reopenClosedTab()

        #expect(store.terminalSessions.map(\.isPlainTerminal) == [true])
        #expect(!store.canReopenClosedTab)
    }

    @Test func aSessionWithATabAgainShowsThatTabRatherThanASecond() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let conversation = sandbox.conversation()
        store.replaceConversations(on: .thisMac, with: [conversation])
        store.launch(conversation, action: .resume)
        store.closeTerminal(try #require(store.runningTerminal(for: conversation)).id)
        store.launch(conversation, action: .resume)
        let tabOpenAgain = try #require(store.runningTerminal(for: conversation))
        store.openPlainTerminal(in: sandbox.projectLocation)

        store.reopenClosedTab()

        #expect(store.terminalSessions.count == 2)
        #expect(store.selectedTerminalID == tabOpenAgain.id)
    }

    @Test func aNewSessionTabWhoseSessionIsNotKnownYetIsNotKept() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let newSessionTab = TerminalSession(
            engine: .swiftTerm,
            conversation: nil,
            provider: .claude,
            projectPath: sandbox.project.path,
            action: .new,
            displayTitle: "New session",
            command: NativeCLICommand(executablePath: "/bin/sh", arguments: [], workingDirectory: sandbox.project.path, environment: [])
        )
        store.openTerminal(newSessionTab)

        store.closeTerminal(newSessionTab.id)

        #expect(!store.canReopenClosedTab)
    }
}
