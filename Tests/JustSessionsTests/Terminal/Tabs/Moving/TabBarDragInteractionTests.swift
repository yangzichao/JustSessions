import Foundation
import Testing
@testable import JustSessions

/// Mouse events on the tab bar itself: a drag moves a tab within its group, a split's two tabs together, or a whole
/// group by its label, while a click still selects a tab, closes it from its ×, or collapses a group.
@MainActor
struct TabBarDragInteractionTests {
    @Test func aClickSelectsATabAndADragMovesItPastHalfItsNeighbor() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let first = fixture.openTab("First", in: "/tmp/app")
        let second = fixture.openTab("Second", in: "/tmp/app")
        let third = fixture.openTab("Third", in: "/tmp/app")
        try await fixture.showTabBar()

        try await fixture.click(atX: fixture.middle(ofTab: second.id))
        #expect(fixture.store.selectedTerminalID == second.id)

        // More than half a tab, less than one and a half: past the second tab only.
        try await fixture.drag(fromX: fixture.middle(ofTab: first.id), by: WorkspaceTabMetrics.maximumWidth * 1.3)

        #expect(fixture.store.terminalSessions.map(\.id) == [second.id, first.id, third.id])
        #expect(fixture.store.selectedTerminalID == first.id)
    }

    @Test func aTabDraggedPastItsGroupsEndStaysInItsGroup() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let first = fixture.openTab("First", in: "/tmp/app")
        let second = fixture.openTab("Second", in: "/tmp/app")
        let tools = fixture.openTab("Tools", in: "/tmp/tools")
        try await fixture.showTabBar()

        try await fixture.drag(fromX: fixture.middle(ofTab: first.id), by: 900)

        #expect(fixture.store.terminalSessions.map(\.id) == [second.id, first.id, tools.id])
    }

    @Test func draggingEitherTabOfASplitMovesBoth() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let left = fixture.openTab("Left", in: "/tmp/app")
        let right = fixture.openTab("Right", in: "/tmp/app")
        let other = fixture.openTab("Other", in: "/tmp/app")
        fixture.store.selectTerminal(left.id)
        fixture.store.splitSelectedTerminal(with: right.id)
        try await fixture.showTabBar()

        try await fixture.drag(fromX: fixture.middle(ofTab: right.id), by: WorkspaceTabMetrics.maximumWidth * 0.8)

        #expect(fixture.store.terminalSessions.map(\.id) == [other.id, left.id, right.id])
        #expect(fixture.store.split(containing: left.id)?.contains(right.id) == true)
    }

    @Test func draggingAGroupLabelMovesTheWholeGroup() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let first = fixture.openTab("First", in: "/tmp/app")
        let second = fixture.openTab("Second", in: "/tmp/app")
        let tools = fixture.openTab("Tools", in: "/tmp/tools")
        try await fixture.showTabBar()

        #expect(fixture.store.selectedTerminalID == tools.id)

        try await fixture.drag(fromX: fixture.middle(ofGroupLabel: "/tmp/tools"), by: -700)

        #expect(fixture.store.terminalSessions.map(\.id) == [tools.id, first.id, second.id])
        // Letting go did not also collapse the group, which would have shown a tab still in sight instead.
        #expect(fixture.store.selectedTerminalID == tools.id)
    }

    @Test func aDragFromATabsCloseButtonClosesNothingButAClickStillDoes() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let first = fixture.openTab("First", in: "/tmp/app")
        fixture.openTab("Second", in: "/tmp/app")
        try await fixture.showTabBar()

        try await fixture.drag(fromX: fixture.middle(ofCloseButtonOf: first.id), by: 40)
        #expect(fixture.closeRequests.isEmpty)

        try await fixture.click(atX: fixture.middle(ofCloseButtonOf: first.id))
        #expect(fixture.closeRequests == [first.id])
    }

    /// Collapsing the selected tab's group shows the nearest tab still in sight.
    @Test func aClickOnAGroupLabelStillCollapsesTheGroup() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let app = fixture.openTab("App", in: "/tmp/app")
        let tools = fixture.openTab("Tools", in: "/tmp/tools")
        fixture.store.selectTerminal(app.id)
        try await fixture.showTabBar()

        try await fixture.click(atX: fixture.middle(ofGroupLabel: "/tmp/app"))

        #expect(fixture.store.selectedTerminalID == tools.id)
    }
}
