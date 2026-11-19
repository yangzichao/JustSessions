import Foundation
import Testing

@testable import JustSessions

struct OpenTabMultiSelectionTests {
    private let tabIDs = (0..<5).map { _ in UUID() }

    @Test func commandClickTogglesRowsIntoAndOutOfSelection() {
        var selection = OpenTabMultiSelection()
        selection.toggle(tabIDs[0])
        selection.toggle(tabIDs[2])
        #expect(selection.selectedTabIDs == [tabIDs[0], tabIDs[2]])
        #expect(selection.hasMultipleSelected)

        selection.toggle(tabIDs[0])
        #expect(selection.selectedTabIDs == [tabIDs[2]])
        #expect(!selection.hasMultipleSelected)
    }

    @Test func shiftClickSelectsRangeFromAnchorInEitherDirection() {
        var selection = OpenTabMultiSelection()
        selection.toggle(tabIDs[1])
        selection.selectRange(to: tabIDs[3], in: tabIDs)
        #expect(selection.selectedTabIDs == Set(tabIDs[1...3]))

        selection.selectRange(to: tabIDs[0], in: tabIDs)
        #expect(selection.selectedTabIDs == Set(tabIDs[0...1]))
        #expect(selection.anchorTabID == tabIDs[1])
    }

    @Test func shiftClickWithoutAnchorInSightSelectsOnlyClickedRow() {
        var selection = OpenTabMultiSelection()
        selection.selectRange(to: tabIDs[2], in: tabIDs)
        #expect(selection.selectedTabIDs == [tabIDs[2]])

        selection.selectRange(to: tabIDs[4], in: Array(tabIDs[3...]))
        #expect(selection.selectedTabIDs == [tabIDs[4]])
        #expect(selection.anchorTabID == tabIDs[4])
    }

    @Test func shownTabStartsShiftAndCommandClicksWhileNothingIsSelected() {
        var shiftSelection = OpenTabMultiSelection()
        shiftSelection.selectShownTabWhileNothingIsSelected(tabIDs[1])
        shiftSelection.selectRange(to: tabIDs[3], in: tabIDs)
        #expect(shiftSelection.selectedTabIDs == Set(tabIDs[1...3]))

        var commandSelection = OpenTabMultiSelection()
        commandSelection.selectShownTabWhileNothingIsSelected(tabIDs[1])
        commandSelection.toggle(tabIDs[4])
        #expect(commandSelection.selectedTabIDs == [tabIDs[1], tabIDs[4]])
    }

    @Test func shownTabLeavesAnExistingSelectionAlone() {
        var selection = OpenTabMultiSelection()
        selection.toggle(tabIDs[0])
        selection.toggle(tabIDs[2])

        selection.selectShownTabWhileNothingIsSelected(tabIDs[4])

        #expect(selection.selectedTabIDs == [tabIDs[0], tabIDs[2]])
        #expect(selection.anchorTabID == tabIDs[2])
    }

    @Test func commandClickOnTheShownTabWithNothingSelectedLeavesNothingSelected() {
        var selection = OpenTabMultiSelection()
        selection.selectShownTabWhileNothingIsSelected(tabIDs[1])
        selection.toggle(tabIDs[1])

        #expect(selection.isEmpty)
    }

    @Test func closedOrHiddenTabsLeaveTheSelectionAndTheAnchor() {
        var selection = OpenTabMultiSelection()
        selection.toggle(tabIDs[0])
        selection.toggle(tabIDs[1])
        selection.toggle(tabIDs[2])

        selection.keepOnly([tabIDs[0], tabIDs[1], tabIDs[3]])

        #expect(selection.selectedTabIDs == [tabIDs[0], tabIDs[1]])
        #expect(selection.anchorTabID == nil)
    }

    @Test func clearEmptiesSelectionAndAnchor() {
        var selection = OpenTabMultiSelection()
        selection.toggle(tabIDs[0])
        selection.toggle(tabIDs[1])

        selection.clear()

        #expect(selection.isEmpty)
        #expect(selection.anchorTabID == nil)
    }

    @Test func rowsInSightLeaveOutCollapsedGroupsUnlessSearching() {
        let groups = TerminalTabGroup.groups(of: ["app/1", "tools/1", "app/2", "docs/1"]) {
            String($0.split(separator: "/")[0])
        }
        var collapse = OpenTabGroupCollapse()
        collapse.toggle("tools")

        #expect(collapse.tabsInSight(of: groups, whileSearching: false) == ["app/1", "app/2", "docs/1"])
        #expect(collapse.tabsInSight(of: groups, whileSearching: true) == ["app/1", "app/2", "tools/1", "docs/1"])
    }
}
