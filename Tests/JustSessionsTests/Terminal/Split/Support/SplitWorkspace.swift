import AppKit
import SwiftUI

@testable import JustSessions

@MainActor
final class SplitWorkspace {
    let store: ConversationStore
    let window: NSWindow
    private let engine: TerminalEngine
    private let settings: IsolatedUserDefaults
    private let hostingView: NSHostingView<AnyView>

    init(engine: TerminalEngine) throws {
        _ = NSApplication.shared
        self.engine = engine
        settings = try IsolatedUserDefaults()
        store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
    }

    func open() -> TerminalSession {
        let tab = TerminalSession(
            engine: engine,
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
        hostingView.rootView = AnyView(
            WorkspaceDetailView(
                store: store,
                sessionSelection: SessionMultiSelection(),
                isSidebarHidden: false,
                onRename: { _ in },
                onNewSession: {},
                onNewSessionInSplitChooser: { _ in },
                onCloseTerminal: { _ in },
                onCloseTabGroup: { _, _ in },
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
