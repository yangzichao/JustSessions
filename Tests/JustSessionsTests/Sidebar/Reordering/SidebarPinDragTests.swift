import CoreGraphics
import Foundation
import Testing

@testable import JustSessions

struct SidebarPinDragTests {
    private let scope = SidebarPinDrag.Scope.projects(on: .thisMac)

    @Test func aPinnedRowMovesAboveTheRowWhoseMiddleThePointerIsAbove() throws {
        let drag = try #require(makeDrag(of: "c", pinned: ["a", "b", "c"], unpinned: ["d"], pointerY: 5))

        #expect(drag.landingGap == 0)
        #expect(drag.placement == .before("a"))
        #expect(drag.landingEdgeY == 0)
    }

    @Test func aPinnedRowMovesDownPastTheMiddlesThePointerPasses() throws {
        let drag = try #require(makeDrag(of: "a", pinned: ["a", "b", "c"], unpinned: ["d"], pointerY: 50))

        #expect(drag.landingGap == 2)
        #expect(drag.placement == .before("c"))
    }

    @Test func aPinnedRowMovesToTheEndOfThePinnedRows() throws {
        let drag = try #require(makeDrag(of: "a", pinned: ["a", "b", "c"], unpinned: ["d"], pointerY: 95))

        #expect(drag.landingGap == 3)
        #expect(drag.placement == .after("c"))
        #expect(drag.landingEdgeY == 93)
    }

    @Test func nothingLandsWhereTheDraggedRowAlreadyIs() throws {
        let onItself = try #require(makeDrag(of: "a", pinned: ["a", "b"], unpinned: [], pointerY: 20))
        let besideItsPlace = try #require(makeDrag(of: "a", pinned: ["a", "b"], unpinned: [], pointerY: 35))

        #expect(onItself.landingGap == nil)
        #expect(besideItsPlace.landingGap == nil)
        #expect(besideItsPlace.placement == nil)
    }

    @Test func nothingLandsAmongTheRowsThatAreNotPinned() throws {
        let drag = try #require(makeDrag(of: "a", pinned: ["a", "b"], unpinned: ["c", "d"], pointerY: 100))

        #expect(drag.landingGap == nil)
        #expect(drag.placement == nil)
        #expect(drag.landingEdgeY == nil)
    }

    @Test func aRowThatIsNotPinnedLandsAmongThePinnedOnes() throws {
        let drag = try #require(makeDrag(of: "e", pinned: ["a", "b", "c"], unpinned: ["d", "e"], pointerY: 35))

        #expect(drag.placement == .before("b"))
    }

    @Test func theFirstRowThatIsNotPinnedMustLeaveItsOwnRowToBePinned() throws {
        let stillOnItself = try #require(makeDrag(of: "c", pinned: ["a", "b"], unpinned: ["c"], pointerY: 70))
        let aboveItself = try #require(makeDrag(of: "c", pinned: ["a", "b"], unpinned: ["c"], pointerY: 55))

        #expect(stillOnItself.landingGap == nil)
        #expect(aboveItself.landingGap == 2)
        #expect(aboveItself.placement == .after("b"))
        #expect(aboveItself.landingEdgeY == 62)
    }

    @Test func withEveryRowPinnedTheLineCanShowAtTheBottomOfTheScope() throws {
        let drag = try #require(makeDrag(of: "a", pinned: ["a", "b"], unpinned: [], pointerY: 200))

        #expect(drag.landingGap == 2)
        #expect(drag.landingEdgeY == 61)
        #expect(drag.placement == .after("b"))
    }

    @Test func withNothingPinnedInSightARowIsPinnedLast() throws {
        let drag = try #require(makeDrag(of: "b", pinned: [], unpinned: ["a", "b"], pointerY: 5))

        #expect(drag.landingGap == 0)
        #expect(drag.placement == .last)
    }

    @Test func rowsOutOfSightStillCountAmongTheGaps() throws {
        let rows = rows(pinned: ["a", "b", "c", "d"], unpinned: [])
        let frames = frames(for: ["a", "b", "c", "d"]).filter { $0.key != rowID("a") && $0.key != rowID("b") }
        let drag = try #require(SidebarPinDrag(scope: scope, dragging: rowID("d"), rows: rows, rowFrames: frames, pointerY: 64))

        #expect(drag.landingGap == 2)
        #expect(drag.placement == .before("c"))
    }

    @Test func aRowThatCantBePinnedCantBeDragged() {
        let pendingRowID = SidebarRowID.pendingNewSession(id: UUID())
        let rows = [SidebarPinDrag.Row(rowID: pendingRowID, pinID: nil, isPinned: false)]

        #expect(SidebarPinDrag(scope: scope, dragging: pendingRowID, rows: rows, rowFrames: [:], pointerY: 0) == nil)
        #expect(SidebarPinDrag(scope: scope, dragging: rowID("missing"), rows: rows, rowFrames: [:], pointerY: 0) == nil)
    }

    @Test func translationIsHowFarThePointerMoved() throws {
        var drag = try #require(makeDrag(of: "a", pinned: ["a", "b"], unpinned: [], pointerY: 10))

        drag.pointerY = 52

        #expect(drag.translation == 42)
    }

    @Test func offTheListToEitherSideNothingLands() throws {
        var drag = try #require(makeDrag(of: "a", pinned: ["a", "b", "c"], unpinned: [], pointerY: 10))

        drag.movePointer(to: CGPoint(x: 100, y: 70))
        #expect(drag.landingGap == 2)

        drag.movePointer(to: CGPoint(x: 300, y: 70))
        #expect(drag.landingGap == nil)
        #expect(drag.placement == nil)
        #expect(drag.landingEdgeY == nil)
        #expect(drag.translation == 60)

        drag.movePointer(to: CGPoint(x: -5, y: 70))
        #expect(drag.landingGap == nil)

        drag.movePointer(to: CGPoint(x: 100, y: 70))
        #expect(drag.placement == .before("c"))
    }

    private func makeDrag(of draggedID: String, pinned: [String], unpinned: [String], pointerY: CGFloat) -> SidebarPinDrag? {
        SidebarPinDrag(
            scope: scope,
            dragging: rowID(draggedID),
            rows: rows(pinned: pinned, unpinned: unpinned),
            rowFrames: frames(for: pinned + unpinned),
            scopeBottom: frames(for: pinned + unpinned).values.map(\.maxY).max(),
            pointerY: pointerY
        )
    }

    private func rows(pinned: [String], unpinned: [String]) -> [SidebarPinDrag.Row] {
        pinned.map { SidebarPinDrag.Row(rowID: rowID($0), pinID: $0, isPinned: true) }
            + unpinned.map { SidebarPinDrag.Row(rowID: rowID($0), pinID: $0, isPinned: false) }
    }

    private func frames(for pinIDs: [String]) -> [SidebarRowID: CGRect] {
        Dictionary(
            uniqueKeysWithValues: pinIDs.enumerated().map { index, pinID in
                (rowID(pinID), CGRect(x: 0, y: CGFloat(index) * 31, width: 200, height: 30))
            })
    }

    private func rowID(_ pinID: String) -> SidebarRowID {
        .project(path: pinID)
    }
}
