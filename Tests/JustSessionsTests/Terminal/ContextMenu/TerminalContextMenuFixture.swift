import AppKit
import Testing

@testable import JustSessions

@MainActor
final class TerminalContextMenuFixture {
    static let projectPath = "/tmp/justsessions-tests/app"

    let store: ConversationStore
    private let isolatedUserDefaults: IsolatedUserDefaults
    private(set) var renamedConversations: [Conversation] = []
    private(set) var tabsAskedToClose: [UUID] = []
    private(set) var conversationsAskedToDelete: [Conversation] = []
    private var windows: [NSWindow] = []

    init() throws {
        isolatedUserDefaults = try IsolatedUserDefaults()
        store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
    }

    func tearDown() {
        store.closeAllTerminals()
        for window in windows {
            window.contentView = nil
            window.close()
        }
        isolatedUserDefaults.removeSuite()
    }

    @discardableResult
    func openTab(
        engine: TerminalEngine, title: String = "Fix the build", conversation: Conversation? = nil, isPlainTerminal: Bool = false,
        projectPath: String = TerminalContextMenuFixture.projectPath, host: SessionHost = .thisMac
    ) -> TerminalSession {
        let tab = TerminalSession(
            engine: engine,
            conversation: conversation,
            provider: isPlainTerminal ? nil : .claude,
            projectPath: projectPath,
            action: isPlainTerminal ? nil : .resume,
            displayTitle: title,
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: []),
            host: host
        )
        store.openTerminal(tab)
        return tab
    }

    /// Puts the tab's terminal in a window that is never shown, as its inset view in a workspace, so a Ghostty terminal
    /// has the surface that holds its text and selection.
    func showInWindow(_ tab: TerminalSession) {
        let insetView = TerminalInsetView(terminalView: tab.terminalView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = insetView
        windows.append(window)
    }

    func menu(
        for tab: TerminalSession, language: String = "en", linkUnderPointer: String? = nil,
        editorStore: ExternalEditorStore = ExternalEditorStore { _ in nil }
    ) -> NSMenu {
        TerminalContextMenu(
            store: store,
            tab: tab,
            onRename: { [weak self] in self?.renamedConversations.append($0) },
            onCloseTab: { [weak self] in self?.tabsAskedToClose.append($0) },
            onDelete: { [weak self] in self?.conversationsAskedToDelete.append($0) },
            linkUnderPointer: linkUnderPointer,
            language: AppInterfaceLanguage(identifier: language),
            editorStore: editorStore
        ).makeMenu()
    }

    static func titles(of menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "—" : $0.title }
    }

    static func item(_ title: String, in menu: NSMenu) throws -> NSMenuItem {
        try #require(menu.items.first { $0.title == title })
    }

    static func choose(_ item: NSMenuItem) throws {
        let action = try #require(item.action)
        #expect(item.isEnabled)
        #expect(NSApplication.shared.sendAction(action, to: item.target, from: item))
    }
}
