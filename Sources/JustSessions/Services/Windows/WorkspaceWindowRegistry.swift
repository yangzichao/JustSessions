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
        /// Whether SwiftUI has put the store's views in a window yet.
        var hasHadWindow = false
    }

    private var workspaces: [Workspace] = []
    /// Opens a workspace window through SwiftUI's `openWindow`, which each workspace window hands over as it appears;
    /// see `handsOverWindowOpening()`.
    var openWorkspaceWindow: (() -> Void)?
    /// Waiting for the windows `openWindow(handingOverTo:)` opened, in order.
    private var windowHandOvers: [(ConversationStore, NSWindow) -> Void] = []

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

    /// The window the store's views show in, once SwiftUI has put them in one. A new window goes to the oldest
    /// waiting hand-over, once SwiftUI has finished putting it on screen.
    func setWindow(_ window: NSWindow?, for store: ConversationStore) {
        guard let index = workspaces.firstIndex(where: { $0.store === store }) else { return }
        workspaces[index].window = window
        guard let window, !workspaces[index].hasHadWindow else { return }
        workspaces[index].hasHadWindow = true
        guard !windowHandOvers.isEmpty else { return }
        let handOver = windowHandOvers.removeFirst()
        DispatchQueue.main.async { handOver(store, window) }
    }

    func window(of store: ConversationStore) -> NSWindow? {
        workspaces.first { $0.store === store }?.window
    }

    /// The workspace window with the window server's number, and its store.
    func workspace(withWindowNumber windowNumber: Int) -> (store: ConversationStore, window: NSWindow)? {
        for workspace in workspaces {
            if let store = workspace.store, let window = workspace.window, window.windowNumber == windowNumber {
                return (store, window)
            }
        }
        return nil
    }

    /// Opens a workspace window and hands its store and window to `handOver` before it has any tabs. Returns false
    /// when no window has handed over SwiftUI's `openWindow` yet.
    @discardableResult
    func openWindow(handingOverTo handOver: @escaping (ConversationStore, NSWindow) -> Void) -> Bool {
        guard let openWorkspaceWindow else { return false }
        windowHandOvers.append(handOver)
        openWorkspaceWindow()
        return true
    }

    /// The windows asked for may never open; any that still do open as usual, empty.
    func cancelWindowHandOvers() {
        windowHandOvers.removeAll()
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
