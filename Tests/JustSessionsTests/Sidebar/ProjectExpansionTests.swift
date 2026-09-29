import Testing
@testable import JustSessions

struct ProjectExpansionTests {
    @Test func togglingOpensAndClosesAProject() {
        var expansion = ProjectExpansion()
        #expect(!expansion.isExpanded("a", whileSearching: false))

        expansion.toggle("a")
        #expect(expansion.isExpanded("a", whileSearching: false))

        expansion.toggle("a")
        #expect(!expansion.isExpanded("a", whileSearching: false))
    }

    @Test func searchingShowsEveryProjectWithoutChangingWhichAreOpen() {
        var expansion = ProjectExpansion()
        expansion.toggle("a")

        #expect(expansion.isExpanded("b", whileSearching: true))
        #expect(expansion.expandedProjectIDs == ["a"])
    }

    @Test func expandingLeavesOpenProjectsOpen() {
        var expansion = ProjectExpansion()
        expansion.toggle("a")

        expansion.expand(["a", "b"])
        #expect(expansion.expandedProjectIDs == ["a", "b"])
    }
}
