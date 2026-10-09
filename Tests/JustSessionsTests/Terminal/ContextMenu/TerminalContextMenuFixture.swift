import AppKit
import Testing
@testable import JustSessions

/// A store with open tabs, the menu a right-click in a tab's terminal shows, and what its items asked the window for.
@MainActor
final class TerminalContextMenuFixture {
    static let projectPath = "/tmp/justsessions-tests/app"

    let store: ConversationStore
    private let isolatedUserDefaults: IsolatedUserDefaults
    private(set) var renamedConversations: [Conversation] = []
    private(set) var tabsAskedToClose: [UUID] = []

    init() throws {
        isolatedUserDefaults = try IsolatedUserDefaults()
        store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
    }

    func tearDown() {
        store.closeAllTerminals()
        isolatedUserDefaults.removeSuite()
    }

    /// Opens and selects a tab, as a new tab is.
    @discardableResult
    func openTab(title: String = "Fix the build", conversation: Conversation? = nil, isPlainTerminal: Bool = false) -> TerminalSession {
        let tab = TerminalSession(
            conversation: conversation,
            provider: isPlainTerminal ? nil : .claude,
            projectPath: Self.projectPath,
            action: isPlainTerminal ? nil : .resume,
            displayTitle: title,
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: Self.projectPath, environment: [])
        )
        store.openTerminal(tab)
        return tab
    }

    func menu(for tab: TerminalSession, language: String = "en") -> NSMenu {
        TerminalContextMenu(
            store: store,
            tab: tab,
            onRename: { [weak self] in self?.renamedConversations.append($0) },
            onCloseTab: { [weak self] in self?.tabsAskedToClose.append($0) },
            language: AppInterfaceLanguage(identifier: language)
        ).makeMenu()
    }

    /// The menu's titles, with "—" for each separator.
    static func titles(of menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "—" : $0.title }
    }

    static func item(_ title: String, in menu: NSMenu) throws -> NSMenuItem {
        try #require(menu.items.first { $0.title == title })
    }

    /// Chooses the item, as a click on it does.
    static func choose(_ item: NSMenuItem) throws {
        let action = try #require(item.action)
        #expect(item.isEnabled)
        #expect(NSApplication.shared.sendAction(action, to: item.target, from: item))
    }
}
