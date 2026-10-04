import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// Reversing, swapping into, or separating a split reorders the tabs, and with them the terminals the workspace lays
/// out. The selected terminal must keep the keyboard through that: if its view were taken out of the window and put
/// back, it would resign first responder and typing would go nowhere until a click.
@MainActor
struct TerminalSplitFocusTests {
    @Test func reorderingTheTabsKeepsTheKeyboardOnTheSelectedTerminal() async throws {
        let workspace = try SplitWorkspace()
        defer { workspace.close() }
        let store = workspace.store
        let first = workspace.open()
        let second = workspace.open()
        let third = workspace.open()
        store.selectTerminal(first.id)
        store.splitSelectedTerminal(with: second.id)
        let split = try #require(store.shownSplit)
        try await workspace.show()
        workspace.window.makeFirstResponder(first.terminalView)
        try #require(workspace.window.firstResponder === first.terminalView)
        let hostsBefore = workspace.terminalHosts(of: [first, second, third])

        store.reverseSplit(split.id)
        try await workspace.settleLayout()
        #expect(store.terminalSessions.map(\.id) == [second.id, first.id, third.id])
        #expect(workspace.window.firstResponder === first.terminalView, "after reversing")

        store.moveIntoShownSplit(third.id, swappingWith: .left)
        try await workspace.settleLayout()
        #expect(store.terminalSessions.map(\.id) == [third.id, first.id, second.id])
        #expect(workspace.window.firstResponder === first.terminalView, "after swapping")

        store.separateSplit(split.id)
        try await workspace.settleLayout()
        #expect(workspace.window.firstResponder === first.terminalView, "after separating")

        // No terminal was taken out of its views and put in new ones.
        #expect(workspace.terminalHosts(of: [first, second, third]) == hostsBefore)
    }
}

/// A workspace detail view in a window, with a store of its own, whose tabs run `cat` so their terminals stay open.
@MainActor
private final class SplitWorkspace {
    let store: ConversationStore
    let window: NSWindow
    private let settings: IsolatedUserDefaults
    private let hostingView: NSHostingView<AnyView>

    init() throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
    }

    func open() -> TerminalSession {
        let tab = TerminalSession(
            conversation: nil,
            provider: nil,
            projectPath: "/tmp/split-focus",
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

    /// The two views each terminal sits in, its inset view and SwiftUI's host for it, which would be new ones had it been
    /// made again. Above them, SwiftUI puts a hidden terminal's host in a view of its own for its opacity and takes it
    /// out when the terminal shows, whatever the tab order, so those views are left out.
    func terminalHosts(of tabs: [TerminalSession]) -> [[ObjectIdentifier?]] {
        tabs.map { tab in
            let insetView = tab.terminalView.superview
            return [insetView.map(ObjectIdentifier.init), insetView?.superview.map(ObjectIdentifier.init)]
        }
    }

    func close() {
        store.closeAllTerminals()
        hostingView.rootView = AnyView(EmptyView())
        window.close()
        settings.removeSuite()
    }
}
