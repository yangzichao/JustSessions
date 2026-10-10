import Testing
@testable import JustSessions

struct SettingsTabSwitcherTests {
    /// Release notes and Send feedback open from General's About section or the Help menu, not from the switcher.
    @Test func theSwitcherLeavesOutPagesOpenedFromGeneralAndKeepsGeneralSelectedForThem() {
        let pagesOpenedFromGeneral: [SettingsTab] = [.releaseNotes, .feedback]
        #expect(SettingsTab.switcherTabs == SettingsTab.allCases.filter { !pagesOpenedFromGeneral.contains($0) })
        for tab in pagesOpenedFromGeneral {
            #expect(tab.switcherTab == .general)
        }
        for tab in SettingsTab.switcherTabs {
            #expect(tab.switcherTab == tab)
        }
    }
}
