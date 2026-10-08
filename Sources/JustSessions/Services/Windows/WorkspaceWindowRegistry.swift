import AppKit

/// The open workspace windows, each with its store, oldest first. A session runs in at most one tab across them:
/// opening it in one window shows its tab in the window that has it, rather than a second tab on the same CLI. See
/// `ConversationStore+OtherWindows`.
@MainActor
final class WorkspaceWindowRegistry {
    /// The app's windows. A store made on its own, as in tests, gets a registry of its own and sees no other window.
    static let shared = WorkspaceWindowRegistry()

    private struct Workspace {
        weak var store: ConversationStore?
        weak var window: NSWindow?
    }

    private var workspaces: [Workspace] = []

    /// Every open window's store, oldest first.
    var stores: [ConversationStore] {
        workspaces.compactMap(\.store)
    }

    func add(_ store: ConversationStore) {
        workspaces.removeAll { $0.store == nil }
        guard !workspaces.contains(where: { $0.store === store }) else { return }
        workspaces.append(Workspace(store: store))
    }

    /// The store's window closed, with all its tabs.
    func remove(_ store: ConversationStore) {
        workspaces.removeAll { $0.store == nil || $0.store === store }
    }

    /// The window the store's views show in, once SwiftUI has put them in one.
    func setWindow(_ window: NSWindow?, for store: ConversationStore) {
        guard let index = workspaces.firstIndex(where: { $0.store === store }) else { return }
        workspaces[index].window = window
    }

    /// Brings the store's window to the front, out of the Dock if it was minimized.
    func bringForward(_ store: ConversationStore) {
        guard let window = workspaces.first(where: { $0.store === store })?.window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    /// The other windows show which sessions this one's tabs run, and what their CLIs do, so they look again.
    func tabsChanged(in store: ConversationStore) {
        for otherStore in stores where otherStore !== store {
            otherStore.objectWillChange.send()
        }
    }
}
