import AppKit

@MainActor
final class WorkspaceWindowRegistry {
    static let shared = WorkspaceWindowRegistry()

    let hostSessionWork = HostSessionWorkCoordinator()
    let latestRemoteHostCopies = LatestRemoteHostCopies()

    private struct Workspace {
        weak var store: ConversationStore?
        weak var window: NSWindow?
        var hasHadWindow = false
    }

    private var workspaces: [Workspace] = []
    private struct DeletionOwner {
        weak var store: ConversationStore?
    }
    private var deletionOwners: [DeletionOwner] = []
    var openWorkspaceWindow: (() -> Void)?
    private var windowHandOvers: [(ConversationStore, NSWindow) -> Void] = []
    let terminalRestarts = TerminalRestartCoordinator()

    var stores: [ConversationStore] {
        workspaces.compactMap(\.store)
    }

    var storesWithSessionWork: [ConversationStore] {
        var result = stores
        for owner in deletionOwners {
            if let store = owner.store, !result.contains(where: { $0 === store }) { result.append(store) }
        }
        return result
    }

    func deletionStarted(in store: ConversationStore) {
        deletionOwners.removeAll { $0.store == nil }
        guard !deletionOwners.contains(where: { $0.store === store }) else { return }
        deletionOwners.append(DeletionOwner(store: store))
    }

    func deletionFinished(in store: ConversationStore) {
        deletionOwners.removeAll { $0.store == nil || $0.store === store }
    }

    func add(_ store: ConversationStore) {
        workspaces.removeAll { $0.store == nil }
        guard !workspaces.contains(where: { $0.store === store }) else { return }
        workspaces.append(Workspace(store: store))
    }

    func remove(_ store: ConversationStore) {
        workspaces.removeAll { $0.store == nil || $0.store === store }
    }

    func setWindowHandingOverItsFirstWindow(_ window: NSWindow?, for store: ConversationStore) {
        guard let index = workspaces.firstIndex(where: { $0.store === store }) else { return }
        workspaces[index].window = window
        guard let window, !workspaces[index].hasHadWindow else { return }
        workspaces[index].hasHadWindow = true
        handOverOutOfSightToTheOldestWaitingHandOver(firstWindow: window, of: store)
    }

    private func handOverOutOfSightToTheOldestWaitingHandOver(firstWindow window: NSWindow, of store: ConversationStore) {
        guard !windowHandOvers.isEmpty else { return }
        let handOver = windowHandOvers.removeFirst()
        let animationBehavior = window.animationBehavior
        window.animationBehavior = .none
        window.alphaValue = 0
        DispatchQueue.main.async {
            window.animationBehavior = animationBehavior
            handOver(store, window)
        }
    }

    var hasWindowOnScreen: Bool {
        workspaces.contains { $0.store != nil && $0.window?.occlusionState.contains(.visible) == true }
    }

    func window(of store: ConversationStore) -> NSWindow? {
        workspaces.first { $0.store === store }?.window
    }

    func workspace(withWindowNumber windowNumber: Int) -> (store: ConversationStore, window: NSWindow)? {
        for workspace in workspaces {
            if let store = workspace.store, let window = workspace.window, window.windowNumber == windowNumber {
                return (store, window)
            }
        }
        return nil
    }

    @discardableResult
    func openWindow(handingOverTo handOver: @escaping (ConversationStore, NSWindow) -> Void) -> Bool {
        guard let openWorkspaceWindow else { return false }
        windowHandOvers.append(handOver)
        openWorkspaceWindow()
        return true
    }

    func cancelWindowHandOvers() {
        windowHandOvers.removeAll()
    }

    func bringForward(_ store: ConversationStore) {
        guard let window = workspaces.first(where: { $0.store === store })?.window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    func tabsChanged(in store: ConversationStore) {
        for otherStore in stores where otherStore !== store {
            otherStore.noteTabStateChanged()
        }
    }
}
