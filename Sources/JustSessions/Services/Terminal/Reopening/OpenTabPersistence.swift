import Foundation

/// One launch-wide snapshot, updated in place per window. An empty second window cannot erase the first's tabs.
@MainActor
final class OpenTabPersistence {
    static let shared = OpenTabPersistence()

    private var haveBeenTaken = false
    private var windowOrder: [UUID] = []
    private var tabsByWindow: [UUID: [ReopenableTerminalTab]] = [:]

    /// The tabs the last quit saved, the first time it is asked; empty after that.
    func take(from userDefaults: UserDefaults) -> [ReopenableTerminalTab] {
        guard !haveBeenTaken else { return [] }
        haveBeenTaken = true
        return TerminalTabsToReopen.load(from: userDefaults).tabs
    }

    func update(_ tabs: [ReopenableTerminalTab], for windowID: UUID, in userDefaults: UserDefaults) {
        if tabsByWindow[windowID] == nil { windowOrder.append(windowID) }
        tabsByWindow[windowID] = tabs
        save(to: userDefaults)
    }

    func removeWindow(_ windowID: UUID, from userDefaults: UserDefaults) {
        tabsByWindow[windowID] = nil
        windowOrder.removeAll { $0 == windowID }
        save(to: userDefaults)
    }

    private func save(to userDefaults: UserDefaults) {
        let snapshot = TerminalTabsToReopen(tabs: windowOrder.flatMap { tabsByWindow[$0] ?? [] })
        guard snapshot != TerminalTabsToReopen.load(from: userDefaults) else { return }
        snapshot.save(to: userDefaults)
    }
}
