import Foundation
import Testing
@testable import JustSessions

@MainActor
struct WorkspacePaneRoutingTests {
    @Test func openingAndSelectingTabsRoutesFocusToTheRightPane() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let docked = Self.terminal(projectPath: "/work/a")
        let plain = Self.terminal(projectPath: "/work/b")
        store.openTerminal(docked)
        store.openTerminal(plain)
        defer { store.closeAllTerminals() }
        store.dockPane(.terminal(docked.id), on: .trailing, of: .selection)
        #expect(store.focusedPaneContent == .terminal(docked.id))

        store.selectTerminal(plain.id)
        #expect(store.focusedPaneContent == .selection)

        // Selecting a docked tab focuses its pane, including when it is already the selected tab.
        store.selectTerminal(docked.id)
        #expect(store.focusedPaneContent == .terminal(docked.id))
        store.focusPane(.selection)
        store.selectTerminal(docked.id)
        #expect(store.focusedPaneContent == .terminal(docked.id))

        let opened = Self.terminal(projectPath: "/work/c")
        store.openTerminal(opened)
        #expect(store.focusedPaneContent == .selection)
        #expect(store.selectedTerminalID == opened.id)
    }

    @Test func splitCommandsDockTheSelectedTabBesideTheFocusedPane() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let first = Self.terminal(projectPath: "/work/a")
        let second = Self.terminal(projectPath: "/work/b")
        store.openTerminal(first)
        store.openTerminal(second)
        defer { store.closeAllTerminals() }

        // ⌘D: the selected tab docks to the right of the selection pane.
        #expect(store.canSplitSelectedTab)
        store.splitSelectedTab(downward: false)
        #expect(store.paneLayout.panes == [.selection, .terminal(second.id)])
        #expect(store.focusedPaneContent == .terminal(second.id))
        // Its own pane focused, the docked tab cannot split against itself.
        #expect(!store.canSplitSelectedTab)

        // ⇧⌘D from the docked pane: the newly selected tab docks below it.
        store.selectTerminal(first.id)
        store.focusPane(.terminal(second.id))
        store.splitSelectedTab(downward: true)
        #expect(store.paneLayout.panes == [.selection, .terminal(second.id), .terminal(first.id)])

        // ⌃⌘W: the focused pane closes, its tab stays open, focus moves to a survivor.
        #expect(store.canCloseFocusedPane)
        store.closeFocusedPane()
        #expect(store.paneLayout.panes == [.selection, .terminal(second.id)])
        #expect(store.terminalSessions.count == 2)
        #expect(store.focusedPaneContent == .terminal(second.id))

        store.focusPane(.selection)
        #expect(!store.canCloseFocusedPane)
        store.closeFocusedPane()
        #expect(store.paneLayout.panes == [.selection, .terminal(second.id)])
    }

    @Test func closingADockedTabsTerminalPrunesItsPaneAndFocus() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let docked = Self.terminal(projectPath: "/work/a")
        store.openTerminal(docked)
        store.dockPane(.terminal(docked.id), on: .bottom, of: .selection)
        #expect(store.focusedPaneContent == .terminal(docked.id))

        store.closeTerminal(docked.id)

        #expect(store.paneLayout == .selectionOnly)
        #expect(store.focusedPaneContent == .selection)
        #expect(store.terminalSessions.isEmpty)
    }

    @Test func deletingAPreviewedSessionClosesItsPaneAndFocusFallsBack() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let kept = Conversation.fixture(projectPath: "/work/kept")
        let previewed = Conversation.fixture(projectPath: "/work/previewed")
        store.replaceConversations(on: .thisMac, with: [kept, previewed])
        store.dockPane(.preview(previewed.id), on: .trailing, of: .selection)
        #expect(store.focusedPaneContent == .preview(previewed.id))

        store.replaceConversations(on: .thisMac, with: [kept])

        #expect(store.paneLayout == .selectionOnly)
        #expect(store.focusedPaneContent == .selection)
    }

    private static func terminal(projectPath: String) -> TerminalSession {
        TerminalSession(
            conversation: nil,
            provider: .pi,
            projectPath: projectPath,
            action: .new,
            displayTitle: "tab",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
    }
}
