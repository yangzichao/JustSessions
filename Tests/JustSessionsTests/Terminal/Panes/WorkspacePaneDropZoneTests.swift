import Foundation
import Testing
@testable import JustSessions

struct WorkspacePaneDropZoneTests {
    private let rect = CGRect(x: 100, y: 50, width: 400, height: 200)

    @Test func edgesTakeTheirBandsAndTheMiddleMoves() {
        #expect(WorkspacePaneDropZone.zone(at: CGPoint(x: 110, y: 150), in: rect) == .edge(.leading))
        #expect(WorkspacePaneDropZone.zone(at: CGPoint(x: 490, y: 150), in: rect) == .edge(.trailing))
        #expect(WorkspacePaneDropZone.zone(at: CGPoint(x: 300, y: 60), in: rect) == .edge(.top))
        #expect(WorkspacePaneDropZone.zone(at: CGPoint(x: 300, y: 240), in: rect) == .edge(.bottom))
        #expect(WorkspacePaneDropZone.zone(at: CGPoint(x: 300, y: 150), in: rect) == .center)
        #expect(WorkspacePaneDropZone.zone(at: CGPoint(x: 50, y: 150), in: rect) == nil)
    }

    @Test func targetsResolvePanesButNotDividers() {
        let terminal = WorkspacePaneContent.terminal(UUID())
        let layout = WorkspacePaneLayout.selectionOnly.docking(terminal, on: .trailing, of: .selection)
        let resolution = WorkspacePaneGeometry.resolve(layout, in: CGRect(x: 0, y: 0, width: 806, height: 400))

        let left = WorkspacePaneDropZone.target(at: CGPoint(x: 200, y: 200), in: resolution)
        #expect(left?.content == .selection)
        #expect(left?.zone == .center)
        let right = WorkspacePaneDropZone.target(at: CGPoint(x: 410, y: 200), in: resolution)
        #expect(right?.content == terminal)
        #expect(right?.zone == .edge(.leading))
        // The divider between them is no drop target.
        #expect(WorkspacePaneDropZone.target(at: CGPoint(x: 403, y: 200), in: resolution) == nil)
        #expect(WorkspacePaneDropZone.target(at: CGPoint(x: 900, y: 200), in: resolution) == nil)
    }

    @Test func highlightsCoverTheHalfAPaneWouldGiveUpOrTheWholePaneForAMove() {
        #expect(WorkspacePaneDropZone.center.highlightRect(in: rect) == rect)
        #expect(WorkspacePaneDropZone.edge(.leading).highlightRect(in: rect)
            == CGRect(x: 100, y: 50, width: 200, height: 200))
        #expect(WorkspacePaneDropZone.edge(.trailing).highlightRect(in: rect)
            == CGRect(x: 300, y: 50, width: 200, height: 200))
        #expect(WorkspacePaneDropZone.edge(.top).highlightRect(in: rect)
            == CGRect(x: 100, y: 50, width: 400, height: 100))
        #expect(WorkspacePaneDropZone.edge(.bottom).highlightRect(in: rect)
            == CGRect(x: 100, y: 150, width: 400, height: 100))
    }
}
