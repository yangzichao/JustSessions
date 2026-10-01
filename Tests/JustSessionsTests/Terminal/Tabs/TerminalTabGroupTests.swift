import Testing
@testable import JustSessions

/// The tab bar shows one group per project, in the order each project's first tab appears, each with its own color.
struct TerminalTabGroupTests {
    private struct Tab: Equatable {
        let name: String
        let projectKey: String
    }

    @Test func tabsGroupByProjectInTheOrderTheirFirstTabAppears() {
        let tabs = [
            Tab(name: "b1", projectKey: "/b"),
            Tab(name: "a1", projectKey: "/a"),
            Tab(name: "b2", projectKey: "/b"),
        ]

        let groups = TerminalTabGroup.groups(of: tabs, projectDirectoryKey: \.projectKey)

        #expect(groups.map(\.projectDirectoryKey) == ["/b", "/a"])
        #expect(groups.map { $0.tabs.map(\.name) } == [["b1", "b2"], ["a1"]])
    }

    @Test func aProjectKeepsTheSameColorFromOneLaunchToTheNext() {
        // FNV-1a of the key is 0xB77B213EF7F43685, in every process, unlike `hashValue`.
        #expect(TabGroupColorAssignment.preferredColorIndex(forProjectKey: "/Users/me/app", paletteSize: 8) == 5)
    }

    @Test func openGroupsGetDifferentColorsWhileThePaletteHasEnough() {
        let projectKeys = (0..<8).map { "/project\($0)" }

        let colorIndices = TabGroupColorAssignment.colorIndices(forProjectKeys: projectKeys, paletteSize: 8)

        #expect(Set(colorIndices).count == 8)
        #expect(colorIndices[0] == TabGroupColorAssignment.preferredColorIndex(forProjectKey: "/project0", paletteSize: 8))
    }

    @Test func groupsBeyondThePaletteReuseTheirPreferredColor() {
        let colorIndices = TabGroupColorAssignment.colorIndices(forProjectKeys: ["/a", "/b", "/c"], paletteSize: 2)

        #expect(colorIndices.count == 3)
        #expect(Set(colorIndices.prefix(2)).count == 2)
        #expect(colorIndices[2] == TabGroupColorAssignment.preferredColorIndex(forProjectKey: "/c", paletteSize: 2))
    }
}
