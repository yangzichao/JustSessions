import Foundation
import Testing
@testable import JustSessions

@MainActor
struct TabNavigationTests {
    @Test func cyclingWrapsAndEntersFromPreviewWithoutReplacingTerminals() throws {
        let sandbox = try TabNavigationSandbox(tabCount: 3)
        defer { sandbox.tearDown() }
        let store = sandbox.store
        let terminalViews = store.terminalSessions.map(\.terminalView)

        store.selectAdjacentTerminal(movingForward: true)
        #expect(store.selectedTerminalID == sandbox.tabs[0].id)
        store.selectAdjacentTerminal(movingForward: false)
        #expect(store.selectedTerminalID == sandbox.tabs[2].id)
        store.selectTerminal(nil)
        store.selectAdjacentTerminal(movingForward: false)
        #expect(store.selectedTerminalID == sandbox.tabs[2].id)
        store.selectTerminal(nil)
        store.selectAdjacentTerminal(movingForward: true)
        #expect(store.selectedTerminalID == sandbox.tabs[0].id)
        store.selectAdjacentTerminal(movingForward: true)
        #expect(store.selectedTerminalID == sandbox.tabs[1].id)
        for (session, terminalView) in zip(store.terminalSessions, terminalViews) {
            #expect(session.terminalView === terminalView)
            #expect(!session.hasExited)
        }
    }

    @Test func numberedShortcutsChoosePositionsAndNineChoosesTheLastOfMoreThanNineTabs() throws {
        let sandbox = try TabNavigationSandbox(tabCount: 11)
        defer { sandbox.tearDown() }
        for shortcutNumber in 1...8 {
            sandbox.store.selectTerminal(shortcutNumber: shortcutNumber)
            #expect(sandbox.store.selectedTerminalID == sandbox.tabs[shortcutNumber - 1].id)
        }
        sandbox.store.selectTerminal(shortcutNumber: 9)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[10].id)
    }

    @Test func unavailableShortcutsAndEmptyWorkspacesLeaveSelectionAlone() throws {
        let sandbox = try TabNavigationSandbox(tabCount: 2)
        defer { sandbox.tearDown() }
        for shortcutNumber in [0, 3, 8, 10] {
            sandbox.store.selectTerminal(shortcutNumber: shortcutNumber)
            #expect(sandbox.store.selectedTerminalID == sandbox.tabs[1].id)
        }
        sandbox.store.closeAllTerminals()
        sandbox.store.selectAdjacentTerminal(movingForward: true)
        sandbox.store.selectAdjacentTerminal(movingForward: false)
        sandbox.store.selectTerminal(shortcutNumber: 1)
        sandbox.store.selectTerminal(shortcutNumber: 9)
        #expect(sandbox.store.selectedTerminalID == nil)
    }

    @Test func closingTheSelectedTabChoosesItsNeighborAndClosingAnotherPreservesSelection() throws {
        let sandbox = try TabNavigationSandbox(tabCount: 4)
        defer { sandbox.tearDown() }
        sandbox.store.selectTerminal(sandbox.tabs[1].id)
        sandbox.store.closeTerminal(sandbox.tabs[1].id)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[2].id)
        sandbox.store.closeTerminal(sandbox.tabs[0].id)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[2].id)
        sandbox.store.selectTerminal(sandbox.tabs[3].id)
        sandbox.store.closeTerminal(sandbox.tabs[3].id)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[2].id)
        sandbox.store.closeTerminal(sandbox.tabs[2].id)
        #expect(sandbox.store.selectedTerminalID == nil)
    }

    @Test func plainTerminalTabsParticipateInSwitchingAndClosing() throws {
        let sandbox = try TabNavigationSandbox(tabCount: 3, plainTerminalAtIndex: 1)
        defer { sandbox.tearDown() }
        sandbox.store.selectTerminal(shortcutNumber: 2)
        #expect(sandbox.store.selectedTerminal?.isPlainTerminal == true)
        sandbox.store.selectAdjacentTerminal(movingForward: true)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[2].id)
        sandbox.store.selectAdjacentTerminal(movingForward: false)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[1].id)
        sandbox.store.closeTerminal(sandbox.tabs[1].id)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[2].id)
    }

    @Test func shortcutsFollowProjectGroupOrderAndClosingStaysInTheProject() throws {
        let sandbox = try TabNavigationSandbox(tabCount: 3, projectPaths: ["/tmp/app", "/tmp/tools", "/tmp/app"])
        defer { sandbox.tearDown() }
        #expect(sandbox.store.terminalSessions.map(\.id) == [sandbox.tabs[0].id, sandbox.tabs[2].id, sandbox.tabs[1].id])
        sandbox.store.selectTerminal(shortcutNumber: 2)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[2].id)
        sandbox.store.selectAdjacentTerminal(movingForward: true)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[1].id)
        sandbox.store.selectAdjacentTerminal(movingForward: true)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[0].id)
        sandbox.store.selectTerminal(shortcutNumber: 2)
        sandbox.store.closeTerminal(sandbox.tabs[2].id)
        #expect(sandbox.store.selectedTerminalID == sandbox.tabs[0].id)
    }
}

/// Unstarted terminals and private settings; no CLI processes or real sessions are touched.
@MainActor
private struct TabNavigationSandbox {
    let store: ConversationStore
    let tabs: [TerminalSession]
    let settings: IsolatedUserDefaults

    init(tabCount: Int, plainTerminalAtIndex: Int? = nil, projectPaths: [String]? = nil) throws {
        settings = try IsolatedUserDefaults()
        store = ConversationStore(
            adapters: [],
            commandResolver: NativeCLICommandResolver(searchDirectories: [], inheritedEnvironment: [:]),
            userDefaults: settings.userDefaults,
            sessionNotifier: RecordingSessionNotifier()
        )
        tabs = (0..<tabCount).map { index in
            TerminalSession(
                conversation: nil, provider: index == plainTerminalAtIndex ? nil : .codex,
                projectPath: projectPaths?[index] ?? "/tmp",
                action: index == plainTerminalAtIndex ? nil : .resume,
                displayTitle: "Tab \(index + 1)",
                command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: [])
            )
        }
        for tab in tabs { store.openTerminal(tab) }
    }

    func tearDown() {
        store.closeAllTerminals()
        settings.removeSuite()
    }
}
