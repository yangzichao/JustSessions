import CoreGraphics
import Testing
@testable import JustSessions

/// Where a dragged tab or group lands as the pointer moves: past a neighbor once it covers half of it, never past
/// either end of the row, with each neighbor it passes slid over by its width.
struct TabBarDragTests {
    @Test func aDragThatHasNotCoveredHalfANeighborLeavesEveryItemInPlace() throws {
        var drag = try #require(TabBarDrag(dragging: "a", among: ["a", "b", "c"], widths: [100, 100, 100], spacing: 0))

        drag.translation = 50

        #expect(drag.targetIndex == 0)
        #expect(drag.orderedItemIDs == ["a", "b", "c"])
        #expect(drag.offset(of: "a") == 50)
        #expect(drag.offset(of: "b") == 0)
    }

    @Test func passingANeighborSlidesItIntoTheDraggedItemsPlace() throws {
        var drag = try #require(TabBarDrag(dragging: "a", among: ["a", "b", "c"], widths: [100, 100, 100], spacing: 0))

        drag.translation = 51

        #expect(drag.targetIndex == 1)
        #expect(drag.orderedItemIDs == ["b", "a", "c"])
        #expect(drag.offset(of: "a") == 51)
        #expect(drag.offset(of: "b") == -100)
        #expect(drag.offset(of: "c") == 0)
    }

    @Test func draggingLeftPassesEachNeighborItsLeadingEdgeCrosses() throws {
        var drag = try #require(TabBarDrag(dragging: "c", among: ["a", "b", "c"], widths: [100, 100, 100], spacing: 10))

        drag.translation = -70
        #expect(drag.targetIndex == 1)
        #expect(drag.offset(of: "b") == 110)
        #expect(drag.offset(of: "a") == 0)

        drag.translation = -180
        #expect(drag.targetIndex == 0)
        #expect(drag.orderedItemIDs == ["c", "a", "b"])
        #expect(drag.offset(of: "a") == 110)
    }

    @Test func theDraggedItemStopsAtEitherEndOfTheRow() throws {
        var drag = try #require(TabBarDrag(dragging: "b", among: ["a", "b", "c"], widths: [100, 100, 100], spacing: 10))

        drag.translation = 1_000
        #expect(drag.offset(of: "b") == 110)
        #expect(drag.targetIndex == 2)

        drag.translation = -1_000
        #expect(drag.offset(of: "b") == -110)
        #expect(drag.targetIndex == 0)
    }

    /// A group much wider than the last one still passes it before the row ends.
    @Test func aWideItemPassesANarrowNeighborAtTheEndOfTheRow() throws {
        var drag = try #require(TabBarDrag(dragging: "wide", among: ["wide", "narrow"], widths: [300, 40], spacing: 14))

        drag.translation = 1_000

        #expect(drag.targetIndex == 1)
        #expect(drag.orderedItemIDs == ["narrow", "wide"])
        #expect(drag.offset(of: "narrow") == -314)
    }

    @Test func aDragNeedsTheDraggedItemInTheRowAndAWidthForEveryItem() {
        #expect(TabBarDrag(dragging: "x", among: ["a", "b"], widths: [100, 100], spacing: 0) == nil)
        #expect(TabBarDrag(dragging: "a", among: ["a", "b"], widths: [100], spacing: 0) == nil)
    }
}
