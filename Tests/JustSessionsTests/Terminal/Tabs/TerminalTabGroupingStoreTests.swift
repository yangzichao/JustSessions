import Foundation
import Testing
@testable import JustSessions

/// The store keeps each project's tabs side by side, so the tab bar's groups follow the store's tab order.
@MainActor
struct TerminalTabGroupingStoreTests {
    @Test func aNewTabJoinsItsProjectsOtherTabs() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }

        let firstAppTab = makeTab(projectPath: "/tmp/app")
        let toolsTab = makeTab(projectPath: "/tmp/tools")
        let secondAppTab = makeTab(projectPath: "/tmp/app")
        store.openTerminal(firstAppTab)
        store.openTerminal(toolsTab)
        store.openTerminal(secondAppTab)

        #expect(store.terminalSessions.map(\.id) == [firstAppTab.id, secondAppTab.id, toolsTab.id])
        #expect(store.selectedTerminalID == secondAppTab.id)
    }

    @Test func closingASelectedTabShowsAnotherTabOfItsProject() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }

        let firstAppTab = makeTab(projectPath: "/tmp/app")
        let toolsTab = makeTab(projectPath: "/tmp/tools")
        let secondAppTab = makeTab(projectPath: "/tmp/app")
        store.openTerminal(firstAppTab)
        store.openTerminal(toolsTab)
        store.openTerminal(secondAppTab)

        store.closeTerminal(secondAppTab.id)
        #expect(store.selectedTerminalID == firstAppTab.id)

        store.closeTerminal(firstAppTab.id)
        #expect(store.selectedTerminalID == toolsTab.id)
    }

    private func makeTab(projectPath: String) -> TerminalSession {
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
