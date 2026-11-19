import Foundation

@MainActor
final class OpenTabPersistence {
    static let shared = OpenTabPersistence()

    private var haveBeenTaken = false
    private var windowOrder: [UUID] = []
    private var tabsByWindow: [UUID: [ReopenableTerminalTab]] = [:]

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
