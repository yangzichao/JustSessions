import Foundation
import Testing
@testable import JustSessions

struct WorkspacePaneLayoutTests {
    private static let tabA = UUID()
    private static let tabB = UUID()
    private let terminalA = WorkspacePaneContent.terminal(tabA)
    private let terminalB = WorkspacePaneContent.terminal(tabB)
    private let preview = WorkspacePaneContent.preview("session-1")

    @Test func dockingSplitsTheTargetOnTheGivenEdge() {
        let layout = WorkspacePaneLayout.selectionOnly

        let right = layout.docking(terminalA, on: .trailing, of: .selection)
        #expect(right == .split(WorkspacePaneSplit(isHorizontal: true, leading: .pane(.selection), trailing: .pane(terminalA))))

        let below = layout.docking(terminalA, on: .bottom, of: .selection)
        #expect(below == .split(WorkspacePaneSplit(isHorizontal: false, leading: .pane(.selection), trailing: .pane(terminalA))))

        let left = layout.docking(terminalA, on: .leading, of: .selection)
        #expect(left.panes == [terminalA, .selection])

        let nested = right.docking(preview, on: .top, of: terminalA)
        #expect(nested.panes == [.selection, preview, terminalA])
    }

    @Test func dockingContentAlreadyInAPaneMovesIt() {
        let layout = WorkspacePaneLayout.selectionOnly
            .docking(terminalA, on: .trailing, of: .selection)
            .docking(terminalB, on: .bottom, of: terminalA)

        let moved = layout.docking(terminalB, on: .leading, of: .selection)

        #expect(moved.panes == [terminalB, .selection, terminalA])
    }

    @Test func dockingTheSelectionAMissingTargetOrItselfChangesNothing() {
        let layout = WorkspacePaneLayout.selectionOnly.docking(terminalA, on: .trailing, of: .selection)

        #expect(layout.docking(.selection, on: .top, of: terminalA) == layout)
        #expect(layout.docking(terminalB, on: .top, of: preview) == layout)
        #expect(layout.docking(terminalA, on: .top, of: terminalA) == layout)
    }

    @Test func closingAPaneGivesItsSpaceToTheSiblingWhereverTheMovedPaneSat() {
        let layout = WorkspacePaneLayout.selectionOnly
            .docking(terminalA, on: .trailing, of: .selection)
            .docking(preview, on: .bottom, of: terminalA)

        #expect(layout.closing(preview) == WorkspacePaneLayout.selectionOnly.docking(terminalA, on: .trailing, of: .selection))
        #expect(layout.closing(terminalA).panes == [.selection, preview])
        #expect(layout.closing(terminalA).closing(preview) == .selectionOnly)
        #expect(layout.closing(.selection) == layout)
        #expect(layout.closing(terminalB) == layout)
    }

    @Test func movingToCenterSwapsPanesAndReplacesForNewContent() {
        let layout = WorkspacePaneLayout.selectionOnly
            .docking(terminalA, on: .trailing, of: .selection)
            .docking(preview, on: .bottom, of: terminalA)

        // Swap is independent of which pane comes first in the tree.
        let swapped = layout.movingToCenter(preview, of: terminalA)
        #expect(swapped.panes == [.selection, preview, terminalA])
        let swappedBack = swapped.movingToCenter(preview, of: terminalA)
        #expect(swappedBack == layout)

        let replaced = layout.movingToCenter(terminalB, of: preview)
        #expect(replaced.panes == [.selection, terminalA, terminalB])

        #expect(layout.movingToCenter(terminalA, of: .selection) == layout)
        #expect(layout.movingToCenter(terminalB, of: terminalB) == layout)
    }

    @Test func closedTerminalsLoseTheirPanesAndFocusMovesToTheSibling() {
        let layout = WorkspacePaneLayout.selectionOnly
            .docking(terminalA, on: .trailing, of: .selection)
            .docking(terminalB, on: .bottom, of: terminalA)

        let oneClosed = layout.closingTerminals(notIn: [Self.tabA])
        #expect(oneClosed.panes == [.selection, terminalA])
        #expect(layout.closingTerminals(notIn: []) == .selectionOnly)

        #expect(layout.focusTarget(afterClosing: terminalB) == terminalA)
        #expect(layout.focusTarget(afterClosing: terminalA) == terminalB)
        #expect(oneClosed.focusTarget(afterClosing: terminalA) == .selection)
    }

    @Test func fractionsStayInTheDividersRangeAndSurviveCoding() throws {
        var split = WorkspacePaneSplit(isHorizontal: true, fraction: 1.4, leading: .pane(.selection), trailing: .pane(terminalA))
        #expect(split.fraction == WorkspacePaneSplit.fractionRange.upperBound)
        split.fraction = -2
        #expect(split.fraction == WorkspacePaneSplit.fractionRange.lowerBound)
        split.fraction = 0.3

        let layout = WorkspacePaneLayout.split(WorkspacePaneSplit(
            isHorizontal: false,
            fraction: 0.6,
            leading: .split(split),
            trailing: .pane(preview)
        ))

        let decoded = try JSONDecoder().decode(WorkspacePaneLayout.self, from: JSONEncoder().encode(layout))
        #expect(decoded == layout)
        #expect(decoded.panes == [.selection, terminalA, preview])
    }
}
