import Testing
@testable import JustSessions

/// Tabs open next to their project's other tabs, and closing one stays in its project while the project has tabs.
/// Collapsing the selected tab's group shows the nearest tab still in sight.
struct TerminalTabOrderTests {
    @Test func aTabOpensAfterItsProjectsLastTab() {
        let tabProjectKeys = ["/a", "/a", "/b", "/c"]

        #expect(TerminalTabOrder.insertionIndex(forProjectKey: "/a", amongTabProjectKeys: tabProjectKeys) == 2)
        #expect(TerminalTabOrder.insertionIndex(forProjectKey: "/b", amongTabProjectKeys: tabProjectKeys) == 3)
    }

    @Test func aTabOfAProjectWithNoTabsOpensAtTheEnd() {
        #expect(TerminalTabOrder.insertionIndex(forProjectKey: "/d", amongTabProjectKeys: ["/a", "/b"]) == 2)
        #expect(TerminalTabOrder.insertionIndex(forProjectKey: "/a", amongTabProjectKeys: []) == 0)
    }

    @Test func closingATabShowsItsRightNeighborInTheSameProject() {
        // Closing the first /b tab leaves ["/a", "/b", "/c"]; the other /b tab took its place.
        #expect(TerminalTabOrder.indexToSelect(afterClosingTabAt: 1, amongTabProjectKeys: ["/a", "/b", "/b", "/c"]) == 1)
    }

    @Test func closingAProjectsLastTabOnTheRightShowsItsLeftNeighborInTheSameProject() {
        // The right neighbor, /c, is another project; the left one, /b, is the same.
        #expect(TerminalTabOrder.indexToSelect(afterClosingTabAt: 2, amongTabProjectKeys: ["/a", "/b", "/b", "/c"]) == 1)
    }

    @Test func closingAProjectsOnlyTabShowsTheNextProjectsTab() {
        #expect(TerminalTabOrder.indexToSelect(afterClosingTabAt: 1, amongTabProjectKeys: ["/a", "/b", "/c"]) == 1)
        #expect(TerminalTabOrder.indexToSelect(afterClosingTabAt: 2, amongTabProjectKeys: ["/a", "/b", "/c"]) == 1)
    }

    @Test func closingTheOnlyTabShowsNone() {
        #expect(TerminalTabOrder.indexToSelect(afterClosingTabAt: 0, amongTabProjectKeys: ["/a"]) == nil)
    }

    @Test func collapsingTheSelectedTabsGroupShowsTheFirstTabToItsRight() {
        #expect(TerminalTabOrder.indexToSelect(afterCollapsingGroupOfTabAt: 1, collapsedProjectKeys: [], amongTabProjectKeys: ["/a", "/b", "/b", "/c"]) == 3)
    }

    @Test func collapsingTheLastGroupShowsTheTabToItsLeft() {
        #expect(TerminalTabOrder.indexToSelect(afterCollapsingGroupOfTabAt: 2, collapsedProjectKeys: [], amongTabProjectKeys: ["/a", "/b", "/b"]) == 0)
    }

    @Test func collapsingSkipsTabsOfGroupsAlreadyCollapsed() {
        let tabProjectKeys = ["/a", "/b", "/c", "/d"]

        #expect(TerminalTabOrder.indexToSelect(afterCollapsingGroupOfTabAt: 1, collapsedProjectKeys: ["/c", "/d"], amongTabProjectKeys: tabProjectKeys) == 0)
    }

    @Test func collapsingWithNoOtherTabInSightKeepsTheSelectedTab() {
        #expect(TerminalTabOrder.indexToSelect(afterCollapsingGroupOfTabAt: 0, collapsedProjectKeys: [], amongTabProjectKeys: ["/a", "/a"]) == nil)
        #expect(TerminalTabOrder.indexToSelect(afterCollapsingGroupOfTabAt: 0, collapsedProjectKeys: ["/b"], amongTabProjectKeys: ["/a", "/b"]) == nil)
    }
}
