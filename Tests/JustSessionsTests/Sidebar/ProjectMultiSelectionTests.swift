import Testing
@testable import JustSessions

struct ProjectMultiSelectionTests {
    private let orderedProjectIDs = ["/work/first", "/work/shared", "ssh://devbox/work/shared", "ssh://devbox/work/last"]

    @Test func commandClickKeepsProjectsOnDifferentHostsIndependent() {
        var selection = ProjectMultiSelection()
        selection.selectOnly("/work/shared")
        selection.toggle("ssh://devbox/work/shared")
        #expect(selection.selectedProjectIDs == ["/work/shared", "ssh://devbox/work/shared"])
        #expect(selection.hasMultipleSelected)

        selection.toggle("/work/shared")
        #expect(selection.selectedProjectIDs == ["ssh://devbox/work/shared"])
        #expect(selection.hasSelection)
        #expect(!selection.hasMultipleSelected)

        selection.toggle("ssh://devbox/work/shared")
        #expect(!selection.hasSelection)
    }

    @Test func shiftClickSelectsDisplayedRangeAcrossHostsAndKeepsAnchor() {
        var selection = ProjectMultiSelection()
        selection.selectOnly("/work/shared")
        selection.selectRange(to: "ssh://devbox/work/last", in: orderedProjectIDs)
        #expect(selection.selectedProjectIDs == ["/work/shared", "ssh://devbox/work/shared", "ssh://devbox/work/last"])

        selection.selectRange(to: "/work/first", in: orderedProjectIDs)
        #expect(selection.selectedProjectIDs == ["/work/first", "/work/shared"])
        #expect(selection.anchorProjectID == "/work/shared")
    }

    @Test func filteringDropsHiddenProjectsAndResetsMissingRangeAnchor() {
        var selection = ProjectMultiSelection()
        selection.selectOnly("/work/first")
        selection.toggle("ssh://devbox/work/last")
        selection.keepOnly(["/work/first", "/work/shared"])
        #expect(selection.selectedProjectIDs == ["/work/first"])
        #expect(selection.anchorProjectID == nil)

        selection.selectRange(to: "/work/shared", in: ["/work/first", "/work/shared"])
        #expect(selection.selectedProjectIDs == ["/work/shared"])
        #expect(selection.anchorProjectID == "/work/shared")
    }

    @Test func plainSelectionReplacesBatchAndClearResetsAnchor() {
        var selection = ProjectMultiSelection()
        selection.selectOnly("/work/first")
        selection.toggle("/work/shared")
        selection.selectOnly("ssh://devbox/work/shared")
        #expect(selection.selectedProjectIDs == ["ssh://devbox/work/shared"])

        selection.clear()
        #expect(!selection.hasSelection)
        #expect(selection.anchorProjectID == nil)
        selection.selectRange(to: "/work/first", in: orderedProjectIDs)
        #expect(selection.selectedProjectIDs == ["/work/first"])
    }
}
