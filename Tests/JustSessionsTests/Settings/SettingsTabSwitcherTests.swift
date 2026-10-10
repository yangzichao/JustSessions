import Testing
@testable import JustSessions

struct SettingsTabSwitcherTests {
    /// Release notes open from General's About section or the Help menu, not from the switcher.
    @Test func theSwitcherLeavesOutReleaseNotesAndKeepsGeneralSelectedForIt() {
        #expect(!SettingsTab.switcherTabs.contains(.releaseNotes))
        #expect(SettingsTab.switcherTabs == SettingsTab.allCases.filter { $0 != .releaseNotes })
        #expect(SettingsTab.releaseNotes.switcherTab == .general)
        for tab in SettingsTab.switcherTabs {
            #expect(tab.switcherTab == tab)
        }
    }
}
