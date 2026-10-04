import Foundation

/// One launch-wide snapshot, updated in place per window. An empty second window cannot erase the first's tabs.
@MainActor
final class OpenTabPersistence {
    static let shared = OpenTabPersistence()

    private var haveBeenTaken = false
    private var windowOrder: [UUID] = []
    private var tabsByWindow: [UUID: [ReopenableTerminalTab]] = [:]

    /// The tabs the last quit, or the last window closed, saved, the first time it is asked; empty after that.
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

    /// Closing one of several windows drops its tabs. Closing the last one keeps them saved, as a quit does, and the
    /// next window to open, in this launch or the next, takes them again.
    func closeWindow(_ windowID: UUID, in userDefaults: UserDefaults) {
        tabsByWindow[windowID] = nil
        windowOrder.removeAll { $0 == windowID }
        if windowOrder.isEmpty {
            haveBeenTaken = false
        } else {
            save(to: userDefaults)
        }
    }

    private func save(to userDefaults: UserDefaults) {
        let snapshot = TerminalTabsToReopen(tabs: windowOrder.flatMap { tabsByWindow[$0] ?? [] })
        guard snapshot != TerminalTabsToReopen.load(from: userDefaults) else { return }
        snapshot.save(to: userDefaults)
    }
}
