import Foundation

/// Hands the tabs of the last quit to one workspace window per launch, and saves every window's tabs as the app quits.
/// Each window has its own tabs, so the first window to open reopens all of them and any other window opens empty;
/// at quit, each window adds its tabs after those of the windows that saved before it.
@MainActor
final class TabsSavedAtQuit {
    static let shared = TabsSavedAtQuit()

    private var haveBeenTaken = false
    /// The tabs saved so far during this quit; nil until the first window saves.
    private var tabsSavedDuringThisQuit: [ReopenableTerminalTab]?

    /// The tabs the last quit saved, the first time it is asked; empty after that.
    func take(from userDefaults: UserDefaults) -> [ReopenableTerminalTab] {
        guard !haveBeenTaken else { return [] }
        haveBeenTaken = true
        return TerminalTabsToReopen.load(from: userDefaults).tabs
    }

    func save(_ tabs: [ReopenableTerminalTab], to userDefaults: UserDefaults) {
        let allTabs = (tabsSavedDuringThisQuit ?? []) + tabs
        tabsSavedDuringThisQuit = allTabs
        TerminalTabsToReopen(tabs: allTabs).save(to: userDefaults)
    }
}
