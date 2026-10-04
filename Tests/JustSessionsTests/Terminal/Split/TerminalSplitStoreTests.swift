import Foundation
import Testing
@testable import JustSessions

/// Splitting links two tabs side by side as Chrome's split view does: the pair outlives the selection, shows
/// while either half is selected, and unlinks when either half closes.
@MainActor
struct TerminalSplitStoreTests {
    @Test func splittingLinksTheTabBesideTheSelectedTab() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let first = makeTab()
        let second = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.selectTerminal(first.id)

        store.splitSelectedTerminal(with: second.id)

        #expect(store.terminalSplitPair == TerminalSplitPair(leadingID: first.id, trailingID: second.id))
        #expect(store.selectedTerminalID == first.id)
        #expect(store.shownSplitPair != nil)
    }

    @Test func splittingNeedsAnotherOpenTab() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let onlyTab = makeTab()
        store.openTerminal(onlyTab)

        store.splitSelectedTerminal(with: onlyTab.id)
        #expect(store.terminalSplitPair == nil)

        store.splitSelectedTerminal(with: UUID())
        #expect(store.terminalSplitPair == nil)
    }

    @Test func selectingATabOutsideThePairHidesTheSplitButKeepsItLinked() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let first = makeTab()
        let second = makeTab()
        let third = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.openTerminal(third)
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.selectTerminal(third.id)
        #expect(store.shownSplitPair == nil)
        #expect(store.terminalSplitPair != nil)

        store.selectTerminal(second.id)
        #expect(store.shownSplitPair == TerminalSplitPair(leadingID: first.id, trailingID: second.id))
    }

    @Test func swappingTradesThePanesSides() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let first = makeTab()
        let second = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.swapSplitSides()

        #expect(store.terminalSplitPair == TerminalSplitPair(leadingID: second.id, trailingID: first.id))
        #expect(store.selectedTerminalID == first.id)
    }

    @Test func leavingTheSplitUnlinksThePairAndKeepsTheTabsOpen() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let first = makeTab()
        let second = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.endSplit()

        #expect(store.terminalSplitPair == nil)
        #expect(store.terminalSessions.count == 2)
        #expect(store.selectedTerminalID == first.id)
    }

    @Test func closingTheShownHalfLeavesTheOtherHalfInFront() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let first = makeTab()
        let second = makeTab()
        // A third tab next to the closed one in the bar would otherwise be the one selected after closing.
        let third = makeTab()
        store.openTerminal(first)
        store.openTerminal(third)
        store.openTerminal(second)
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.closeTerminal(first.id)

        #expect(store.terminalSplitPair == nil)
        #expect(store.selectedTerminalID == second.id)
    }

    @Test func closingTheHiddenHalfKeepsTheSelectionAndUnlinks() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let first = makeTab()
        let second = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.closeTerminal(second.id)

        #expect(store.terminalSplitPair == nil)
        #expect(store.selectedTerminalID == first.id)
    }

    @Test func closingATabOutsideThePairKeepsTheSplit() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let first = makeTab()
        let second = makeTab()
        let third = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.openTerminal(third)
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.closeTerminal(third.id)

        #expect(store.terminalSplitPair == TerminalSplitPair(leadingID: first.id, trailingID: second.id))
    }

    @Test func splittingAgainReplacesThePair() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let first = makeTab()
        let second = makeTab()
        let third = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.openTerminal(third)
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.splitSelectedTerminal(with: third.id)

        #expect(store.terminalSplitPair == TerminalSplitPair(leadingID: first.id, trailingID: third.id))
    }

    @Test func aTabReplacedInPlaceKeepsItsSideOfTheSplit() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let first = makeTab()
        let second = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        let replacement = makeTab()
        let index = try #require(store.terminalSessions.firstIndex { $0.id == second.id })
        store.replaceTerminal(at: index, with: replacement)

        #expect(store.terminalSplitPair == TerminalSplitPair(leadingID: first.id, trailingID: replacement.id))
    }

    @Test func closingAllTabsUnlinksThePair() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let first = makeTab()
        let second = makeTab()
        store.openTerminal(first)
        store.openTerminal(second)
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)

        store.closeAllTerminals()

        #expect(store.terminalSplitPair == nil)
    }

    private func makeTab(projectPath: String = "/tmp/app") -> TerminalSession {
        TerminalSession(
            conversation: nil,
            provider: .claude,
            projectPath: projectPath,
            action: .resume,
            displayTitle: "Tab in \(projectPath)",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
    }
}
