import Testing
@testable import JustSessions

struct OpenTabGroupCollapseTests {
    @Test func groupsStartExpandedAndToggle() {
        var collapse = OpenTabGroupCollapse()
        #expect(!collapse.isCollapsed("a", whileSearching: false))

        collapse.toggle("a")
        #expect(collapse.isCollapsed("a", whileSearching: false))

        collapse.toggle("a")
        #expect(!collapse.isCollapsed("a", whileSearching: false))
    }

    @Test func searchingShowsEveryGroupWithoutChangingWhichAreCollapsed() {
        var collapse = OpenTabGroupCollapse()
        collapse.toggle("a")

        #expect(!collapse.isCollapsed("a", whileSearching: true))
        #expect(collapse.collapsedProjectKeys == ["a"])
    }

    @Test func expandingOpensOnlyThatGroup() {
        var collapse = OpenTabGroupCollapse()
        collapse.toggle("a")
        collapse.toggle("b")

        collapse.expand("a")
        #expect(collapse.collapsedProjectKeys == ["b"])
    }

    @Test func aGroupWhoseTabsAllClosedOpensExpandedNextTime() {
        var collapse = OpenTabGroupCollapse()
        collapse.toggle("a")
        collapse.toggle("b")

        collapse.keepOnly(["b", "c"])
        #expect(collapse.collapsedProjectKeys == ["b"])
    }
}
