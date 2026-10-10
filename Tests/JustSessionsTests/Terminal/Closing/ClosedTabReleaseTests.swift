import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// A closed tab's terminal is freed once the workspace that showed it goes, as when its window closes, rather than
/// living for the app's life, as it did while the closures the workspace gave it held its tab. A Ghostty terminal
/// holds a GPU surface and its scrollback until it is freed. While the window stays open, AppKit can still hold the
/// closed terminal that last had the keyboard.
@MainActor
struct ClosedTabReleaseTests {
    @Test(arguments: TerminalEngine.allCases)
    func aClosedTabsTerminalIsFreedOnceItsWorkspaceGoes(_ engine: TerminalEngine) async throws {
        let workspace = try ShownWorkspace()
        defer { workspace.close() }
        _ = workspace.open(engine: engine)
        weak var closedTab: TerminalSession?
        weak var closedTerminal: NSView?
        do {
            let tab = workspace.open(engine: engine)
            workspace.store.selectTerminal(tab.id)
            try await workspace.show()
            try #require(tab.terminalView.window === workspace.window)
            closedTab = tab
            closedTerminal = tab.terminalView
            workspace.store.closeTerminal(tab.id, endingTmuxSession: false)
        }
        try await workspace.settleLayout()

        workspace.removeWorkspace()
        try await workspace.settleLayout()

        #expect(closedTab == nil, "the closed tab's session is still alive")
        #expect(closedTerminal == nil, "the closed tab's terminal view is still alive")
    }
}

/// A workspace detail view in a window, with a store of its own, whose tabs run `cat` so their terminals stay open.
@MainActor
private final class ShownWorkspace {
    let store: ConversationStore
    let window: NSWindow
    private let settings: IsolatedUserDefaults
    private let hostingView: NSHostingView<AnyView>

    init() throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
    }

    func open(engine: TerminalEngine) -> TerminalSession {
        let tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: nil,
            projectPath: "/tmp/closed-tab-release",
            action: nil,
            displayTitle: "Terminal",
            command: NativeCLICommand(executablePath: "/bin/cat", arguments: [], workingDirectory: "/tmp", environment: [])
        )
        store.openTerminal(tab)
        return tab
    }

    func show() async throws {
        hostingView.rootView = AnyView(WorkspaceDetailView(
            store: store,
            sessionSelection: SessionMultiSelection(),
            isSidebarHidden: false,
            onRename: { _ in },
            onCloseTerminal: { _ in },
            onDelete: { _ in }
        ))
        try await settleLayout()
    }

    func settleLayout() async throws {
        for _ in 0..<8 {
            hostingView.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    /// What closing the window does to the workspace's views.
    func removeWorkspace() {
        hostingView.rootView = AnyView(EmptyView())
    }

    func close() {
        store.closeAllTerminals()
        hostingView.rootView = AnyView(EmptyView())
        window.close()
        settings.removeSuite()
    }
}
