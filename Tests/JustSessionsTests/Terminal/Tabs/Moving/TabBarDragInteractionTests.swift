import Foundation
import Testing
@testable import JustSessions

/// Mouse events on the tab bar itself: a drag moves a tab within its group, a split's two tabs together, or a whole
/// group by its label, while a click still selects a tab, closes it from its ×, or collapses a group. The bar's space
/// around and past them moves the window instead.
@MainActor
struct TabBarDragInteractionTests {
    @Test func theBarsEmptySpaceMovesTheWindowButItsTabsAndLabelsDont() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let first = fixture.openTab("First", in: "/tmp/app")
        let second = fixture.openTab("Second", in: "/tmp/app")
        let tools = fixture.openTab("Tools", in: "/tmp/tools")
        try await fixture.showTabBar()

        var keptPlaces = [
            "the app label": try fixture.middle(ofGroupLabel: "/tmp/app"),
            "the tools label": try fixture.middle(ofGroupLabel: "/tmp/tools"),
        ]
        for tab in [first, second, tools] {
            keptPlaces[tab.displayTitle] = try fixture.middle(ofTab: tab.id)
            keptPlaces["\(tab.displayTitle)'s ×"] = try fixture.middle(ofCloseButtonOf: tab.id)
        }
        for (name, x) in keptPlaces {
            #expect(try fixture.response(toPressAtX: x) == .holdWindowStill, "\(name)")
        }

        let emptyPlaces = [
            "the bar's leading inset": WorkspaceTabMetrics.horizontalInset / 2,
            "after the app label": try fixture.gap(afterGroupLabel: "/tmp/app"),
            "between the groups": try fixture.gap(beforeGroup: "/tmp/tools"),
            "the bar's empty end": fixture.emptyEndOfTheBar,
        ]
        for (name, x) in emptyPlaces {
            #expect(try fixture.response(toPressAtX: x) == .moveWindow, "\(name)")
        }
    }

    /// A sheet's click-outside monitor closes it on a press anywhere in the window, the tab bar included. Both monitors
    /// see presses first, in an order AppKit doesn't promise, so the bar lets them pass rather than move the window.
    @Test func whileASheetCoversTheWindowPressesOnTheBarPassToIt() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let first = fixture.openTab("First", in: "/tmp/app")
        try await fixture.showTabBar()
        let endSheet = try await fixture.beginSheet()
        defer { endSheet() }

        #expect(try fixture.response(toPressAtX: fixture.emptyEndOfTheBar) == .pass)
        #expect(try fixture.response(toPressAtX: fixture.middle(ofTab: first.id)) == .pass)
    }

    /// The window server can start moving the window from the title bar before the app sees a press, so the window is
    /// unmovable for as long as the pointer is over the bar, and movable again once it leaves, as the Window menu's
    /// Move & Resize items need.
    @Test func theWindowCantMoveWhileThePointerIsOverTheBar() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        fixture.openTab("First", in: "/tmp/app")
        try await fixture.showTabBar()
        #expect(fixture.isWindowMovable)

        try fixture.movePointer(intoTheBar: true)
        #expect(!fixture.isWindowMovable)

        try fixture.movePointer(intoTheBar: false)
        #expect(fixture.isWindowMovable)
    }

    /// The pointer can be over the bar without having entered it, as when the window opens under it.
    @Test func aPressOnATabHoldsTheWindowStillUntilLetGoOffTheBar() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let first = fixture.openTab("First", in: "/tmp/app")
        try await fixture.showTabBar()

        let x = try fixture.middle(ofTab: first.id)
        try await fixture.press(atX: x)
        #expect(!fixture.isWindowMovable)

        try await fixture.release(atX: x, droppedBy: 200)
        #expect(fixture.isWindowMovable)
    }

    /// Where the tab cannot leave for another window, as here, where the bar's window is no workspace window, the
    /// pointer can leave the bar and the tab still follows it along the bar.
    @Test func aTabDraggedOutOfTheBarStillMovesAlongIt() async throws {
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let first = fixture.openTab("First", in: "/tmp/app")
        let second = fixture.openTab("Second", in: "/tmp/app")
        let third = fixture.openTab("Third", in: "/tmp/app")
        try await fixture.showTabBar()

        try await fixture.drag(
            fromX: fixture.middle(ofTab: first.id), by: WorkspaceTabMetrics.maximumWidth * 1.3, droppingBy: 400
        )

        #expect(fixture.store.terminalSessions.map(\.id) == [second.id, first.id, third.id])
    }

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

    /// A tab started from a tab's menu in a collapsed group is selected, so its group expands to show it.
    @Test func aTabStartedFromATabsMenuExpandsItsCollapsedGroup() async throws {
        let project = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        let fixture = try TabBarWindowFixture()
        defer { fixture.close() }
        let app = fixture.openTab("App", in: project.path)
        let tools = fixture.openTab("Tools", in: "/tmp/tools")
        fixture.store.selectTerminal(app.id)
        try await fixture.showTabBar()
        try await fixture.click(atX: fixture.middle(ofGroupLabel: app.projectDirectoryKey))
        try #require(fixture.store.selectedTerminalID == tools.id)

        fixture.store.openPlainTerminal(inGroupOf: app)
        try await fixture.settle()
        let newTab = try #require(fixture.store.terminalSessions.first { $0.id != app.id && $0.id != tools.id })
        #expect(fixture.store.tabGroupKey(of: newTab) == app.projectDirectoryKey)
        #expect(fixture.store.selectedTerminalID == newTab.id)

        // Where the app tab sits only while its group is expanded.
        try await fixture.click(atX: fixture.middle(ofTab: app.id))
        #expect(fixture.store.selectedTerminalID == app.id)
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
