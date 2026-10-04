import Foundation
import Testing
@testable import JustSessions

struct WorkspacePaneGeometryTests {
    private let terminalA = WorkspacePaneContent.terminal(UUID())
    private let terminalB = WorkspacePaneContent.terminal(UUID())
    private static let bounds = CGRect(x: 0, y: 0, width: 801, height: 601)

    @Test func aSinglePaneFillsTheWholeArea() {
        let resolution = WorkspacePaneGeometry.resolve(.selectionOnly, in: Self.bounds)

        #expect(resolution.paneRects == [.selection: Self.bounds])
        #expect(resolution.dividers.isEmpty)
    }

    @Test func panesAndDividersTileTheAreaOnWholePoints() {
        let layout = WorkspacePaneLayout.selectionOnly
            .docking(terminalA, on: .trailing, of: .selection)
            .docking(terminalB, on: .bottom, of: terminalA)
            .settingFraction(1 / 3, atSplitIndex: 0)

        let resolution = WorkspacePaneGeometry.resolve(layout, in: Self.bounds)

        let allRects = Array(resolution.paneRects.values) + resolution.dividers.map(\.rect)
        for rect in allRects {
            #expect(rect.minX == rect.minX.rounded() && rect.minY == rect.minY.rounded())
            #expect(rect.width == rect.width.rounded() && rect.height == rect.height.rounded())
        }
        let tiledArea = allRects.reduce(0) { $0 + $1.width * $1.height }
        #expect(tiledArea == Self.bounds.width * Self.bounds.height)
        for rect in allRects {
            #expect(Self.bounds.contains(rect))
        }
        #expect(resolution.paneRects[.selection]?.width == ((Self.bounds.width - 6) / 3).rounded())
        #expect(resolution.dividers.count == 2)
    }

    /// Divider indices must address the split they came from: setting a fraction through a divider's index moves
    /// that divider where the fraction says, for every divider in a nested tree.
    @Test func dividerIndicesAddressTheirOwnSplits() {
        let layout = WorkspacePaneLayout.selectionOnly
            .docking(terminalA, on: .trailing, of: .selection)
            .docking(terminalB, on: .bottom, of: terminalA)
            .docking(.preview("p"), on: .leading, of: .selection)

        for divider in WorkspacePaneGeometry.resolve(layout, in: Self.bounds).dividers {
            let updated = layout.settingFraction(0.42, atSplitIndex: divider.splitIndex)
            let movedDivider = WorkspacePaneGeometry.resolve(updated, in: Self.bounds).dividers
                .first { $0.splitIndex == divider.splitIndex }!
            let available = (movedDivider.isHorizontal ? movedDivider.splitBounds.width : movedDivider.splitBounds.height)
                - WorkspacePaneGeometry.dividerThickness
            let leadingLength = movedDivider.isHorizontal
                ? movedDivider.rect.minX - movedDivider.splitBounds.minX
                : movedDivider.rect.minY - movedDivider.splitBounds.minY
            #expect(leadingLength == (available * 0.42).rounded())
        }
    }

    @Test func dragFractionsRoundAndKeepTheMinimumPaneLength() {
        let splitBounds = CGRect(x: 0, y: 0, width: 806, height: 400)

        #expect(WorkspacePaneGeometry.fraction(forLeadingLength: 400.4, in: splitBounds, isHorizontal: true) == 0.5)
        #expect(WorkspacePaneGeometry.fraction(forLeadingLength: 10, in: splitBounds, isHorizontal: true) == 0.15)
        #expect(WorkspacePaneGeometry.fraction(forLeadingLength: 5_000, in: splitBounds, isHorizontal: true) == 0.85)

        // A split too small for two minimum panes centers instead of crossing its own ends.
        let tight = CGRect(x: 0, y: 0, width: 206, height: 400)
        #expect(WorkspacePaneGeometry.fraction(forLeadingLength: 0, in: tight, isHorizontal: true) == 0.5)
    }
}
