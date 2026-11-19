import Observation
import Testing

@testable import JustSessions

/// A drag along the tab bar is drawn so that a move of the pointer re-runs only the shifts of the tabs or groups: the
/// placement, which the tabs, their groups, and the bar read, changes only as the drag starts or ends, or as the
/// dragged item passes another.
@MainActor
struct TabBarDragDisplayTests {
    @Test func aMoveWithinTheDraggedItemsPlaceChangesOnlyTheDrag() throws {
        let display = TabBarDragDisplay<String>()
        var drag = try #require(TabBarDrag(dragging: "a", among: ["a", "b", "c"], widths: [100, 100, 100], spacing: 0))
        display.show(drag)

        drag.translation = 40
        let changes = observedChanges(of: display) { display.show(drag) }

        #expect(changes == [.drag])
        #expect(display.drag?.offset(of: "a") == 40)
        #expect(display.placement?.targetIndex == 0)
    }

    @Test func passingANeighborChangesThePlacement() throws {
        let display = TabBarDragDisplay<String>()
        var drag = try #require(TabBarDrag(dragging: "a", among: ["a", "b", "c"], widths: [100, 100, 100], spacing: 0))
        display.show(drag)

        drag.translation = 51
        let changes = observedChanges(of: display) { display.show(drag) }

        #expect(changes == [.drag, .placement])
        #expect(display.placement?.orderedItemIDs == ["b", "a", "c"])
    }

    @Test func showingTheSameDragAgainChangesNothing() throws {
        let display = TabBarDragDisplay<String>()
        let drag = try #require(TabBarDrag(dragging: "a", among: ["a", "b", "c"], widths: [100, 100, 100], spacing: 0))
        display.show(drag)

        let changes = observedChanges(of: display) { display.show(drag) }

        #expect(changes.isEmpty)
    }

    @Test func startingAndEndingADragChangeBoth() throws {
        let display = TabBarDragDisplay<String>()
        let drag = try #require(TabBarDrag(dragging: "a", among: ["a", "b", "c"], widths: [100, 100, 100], spacing: 0))

        #expect(observedChanges(of: display) { display.show(drag) } == [.drag, .placement])
        #expect(observedChanges(of: display) { display.show(nil) } == [.drag, .placement])
        #expect(display.placement == nil)
        #expect(observedChanges(of: display) { display.show(nil) }.isEmpty)
    }

    // MARK: - Helpers

    private enum Property: Hashable {
        case drag
        case placement
    }

    /// The display's properties that views reading them would see change through `change`.
    private func observedChanges(of display: TabBarDragDisplay<String>, through change: () -> Void) -> Set<Property> {
        let changes = ObservedChanges()
        withObservationTracking {
            _ = display.drag
        } onChange: {
            changes.insert(.drag)
        }
        withObservationTracking {
            _ = display.placement
        } onChange: {
            changes.insert(.placement)
        }
        change()
        return changes.properties
    }

    /// Filled in from observation's change handlers, which run synchronously as a property changes.
    private final class ObservedChanges: @unchecked Sendable {
        private(set) var properties: Set<Property> = []
        func insert(_ property: Property) { properties.insert(property) }
    }
}
