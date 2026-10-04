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
    /// The first-saved window's pane layout. Its tabs sit first in the saved order, so the layout's places hold.
    private var paneLayoutSavedDuringThisQuit: SavedPaneLayout?

    /// The tabs the last quit saved, the first time it is asked; empty after that.
    func take(from userDefaults: UserDefaults) -> [ReopenableTerminalTab] {
        takeSavedState(from: userDefaults).tabs
    }

    /// Everything the last quit saved, the first time it is asked; empty after that.
    func takeSavedState(from userDefaults: UserDefaults) -> TerminalTabsToReopen {
        guard !haveBeenTaken else { return TerminalTabsToReopen() }
        haveBeenTaken = true
        return TerminalTabsToReopen.load(from: userDefaults)
    }

    func save(_ tabs: [ReopenableTerminalTab], paneLayout: SavedPaneLayout? = nil, to userDefaults: UserDefaults) {
        let allTabs = (tabsSavedDuringThisQuit ?? []) + tabs
        if tabsSavedDuringThisQuit == nil { paneLayoutSavedDuringThisQuit = paneLayout }
        tabsSavedDuringThisQuit = allTabs
        TerminalTabsToReopen(tabs: allTabs, paneLayout: paneLayoutSavedDuringThisQuit).save(to: userDefaults)
    }
}
