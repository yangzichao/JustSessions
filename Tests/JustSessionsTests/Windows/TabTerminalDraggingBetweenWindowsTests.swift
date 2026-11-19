import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
struct TabTerminalDraggingBetweenWindowsTests {
    @Test(arguments: TerminalEngine.allCases)
    func aDraggedTabsTerminalKeepsItsScreenAndTakesTyping(engine: TerminalEngine) async throws {
        let first = try WorkspaceWindow()
        let second = try WorkspaceWindow()
        defer {
            first.close()
            second.close()
        }
        let tab = first.openEchoingTab(engine: engine)
        try await first.show()
        try await expectEventually { screenText(of: tab.terminalView).contains("BEFORE-MOVE") }
        let ghosttyView = tab.terminalView as? GhosttyTabTerminalView
        let surface = ghosttyView?.terminalSurface
        let controller = ghosttyView?.controller
        if engine == .ghostty { #expect(surface != nil) }

        let tabs = try #require(first.store.takeOutTabsForAnotherWindow([tab.id]))
        second.store.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(0), selecting: tab.id)
        try await second.show()
        try await first.settleLayout()

        #expect(tab.terminalView.window === second.window)
        #expect(!tab.hasExited)
        if let ghosttyView {
            #expect(ghosttyView.terminalSurface === surface)
            #expect(ghosttyView.controller === controller)
        }
        #expect(screenText(of: tab.terminalView).contains("BEFORE-MOVE"))
        second.window.makeFirstResponder(tab.terminalView)
        for character in "moved" {
            tab.terminalView.keyDown(with: SyntheticKey.event(keyCode: 0, characters: String(character), window: second.window))
        }
        tab.terminalView.keyDown(with: SyntheticKey.event(keyCode: 36, characters: "\r", window: second.window))
        try await expectEventually { screenText(of: tab.terminalView).contains("GOT:moved") }
    }

    @Test(arguments: TerminalEngine.allCases)
    func aDraggedTabsTerminalKeepsItsClickMenuAndLinkHandling(engine: TerminalEngine) async throws {
        let first = try WorkspaceWindow()
        let second = try WorkspaceWindow()
        defer {
            first.close()
            second.close()
        }
        let tab = first.openEchoingTab(engine: engine)
        try await first.show()
        try await second.show()

        let tabs = try #require(first.store.takeOutTabsForAnotherWindow([tab.id]))
        second.store.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(0), selecting: tab.id)
        try await second.settleLayout()
        try await first.settleLayout()

        #expect(tab.terminalView.window === second.window)
        #expect(tab.terminalView.onFocus != nil)
        #expect(tab.terminalView.makeContextMenu != nil)
        #expect(tab.terminalView.onOpenLink != nil)
    }

    @Test(arguments: TerminalEngine.allCases)
    func aClosedTabsTerminalLetsGoOfItsHandling(engine: TerminalEngine) async throws {
        let window = try WorkspaceWindow()
        defer { window.close() }
        let tab = window.openEchoingTab(engine: engine)
        try await window.show()
        #expect(tab.terminalView.onOpenLink != nil)

        window.store.closeTerminal(tab.id)
        try await window.settleLayout()

        #expect(tab.terminalView.onFocus == nil)
        #expect(tab.terminalView.makeContextMenu == nil)
        #expect(tab.terminalView.onOpenLink == nil)
    }
}

@MainActor
private final class WorkspaceWindow {
    let store: ConversationStore
    let window: NSWindow
    private let settings: IsolatedUserDefaults
    private let hostingView: NSHostingView<AnyView>

    init() throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
    }

    func openEchoingTab(engine: TerminalEngine) -> TerminalSession {
        let script = "printf 'BEFORE-MOVE\\n'; while read line; do echo \"GOT:$line\"; done"
        let tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: nil,
            projectPath: "/tmp/dragging-between-windows",
            action: nil,
            displayTitle: "Terminal",
            command: NativeCLICommand(
                executablePath: "/bin/sh",
                arguments: ["-c", script],
                workingDirectory: "/tmp",
                environment: ["PATH=/usr/bin:/bin", "TERM=xterm-256color", "LANG=en_US.UTF-8"]
            )
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

    func close() {
        store.closeAllTerminals()
        hostingView.rootView = AnyView(EmptyView())
        window.close()
        settings.removeSuite()
    }
}
