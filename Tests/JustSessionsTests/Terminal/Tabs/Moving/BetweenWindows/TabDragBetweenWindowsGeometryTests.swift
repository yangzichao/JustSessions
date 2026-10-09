import CoreGraphics
import Foundation
import Testing
@testable import JustSessions

/// Where a tab dragged between windows joins or leaves a tab bar, where it goes in the bar, and where the window
/// carrying it goes, worked out from the windows' frames and the bars' layouts in screen and window coordinates.
struct TabDragBetweenWindowsGeometryTests {
    // MARK: - The tab bar's band

    /// A window 800 points wide and 600 high, its top edge at 1000.
    private let band = TabBarBand(windowFrame: CGRect(x: 100, y: 400, width: 800, height: 600))

    @Test func aTabJoinsTheBarOnlyOverIt() {
        #expect(band.takesTab(at: CGPoint(x: 500, y: 990)))
        #expect(band.takesTab(at: CGPoint(x: 101, y: 1000 - TabBarBand.height)))
        #expect(!band.takesTab(at: CGPoint(x: 500, y: 1000 - TabBarBand.height - 1)))
        #expect(!band.takesTab(at: CGPoint(x: 500, y: 1001)))
        #expect(!band.takesTab(at: CGPoint(x: 99, y: 990)))
    }

    /// As Chrome's tab strip holds a dragged tab within `kVerticalDetachMagnetism` of it.
    @Test func aTabInTheBarStaysUntilDraggedWellAboveOrBelowItOrPastTheWindowsSides() {
        let barBottom = 1000 - TabBarBand.height
        #expect(band.holdsTab(at: CGPoint(x: 500, y: barBottom - TabBarBand.detachDistance)))
        #expect(!band.holdsTab(at: CGPoint(x: 500, y: barBottom - TabBarBand.detachDistance - 1)))
        #expect(band.holdsTab(at: CGPoint(x: 500, y: 1000 + TabBarBand.detachDistance)))
        #expect(!band.holdsTab(at: CGPoint(x: 500, y: 1000 + TabBarBand.detachDistance + 1)))
        #expect(band.holdsTab(at: CGPoint(x: 900, y: 990)))
        #expect(!band.holdsTab(at: CGPoint(x: 901, y: 990)))
    }

    // MARK: - The tab bar's layout

    @Test func tabsSpanFromTheirGroupsLeadingEdge() throws {
        let layout = makeLayout()

        let split = try #require(layout.span(ofTabs: [tabID(1), tabID(2)], inGroup: "/a"))
        #expect(split == TabBarLayout.Span(minX: 340, width: 200))
        #expect(layout.span(ofTabs: [tabID(3)], inGroup: "/b") == TabBarLayout.Span(minX: 594, width: 200))
        #expect(layout.groupsLeadingEdge == 200)
    }

    @Test func tabsNotLaidOutYetHaveNoSpan() {
        let layout = makeLayout()

        #expect(layout.span(ofTabs: [tabID(1), tabID(4)], inGroup: "/a") == nil)
        #expect(layout.span(ofTabs: [tabID(3)], inGroup: "/c") == nil)
    }

    /// The tabs go past each unit whose middle is before their leading edge, or as a new group, past each group whose
    /// middle is before the new group's leading edge, its label 40 points before the tabs'.
    @Test func droppedTabsGoBetweenTheTabsOrGroupsAroundTheirLeadingEdge() {
        let layout = makeLayout()
        let strip = makeStrip()

        #expect(placement(of: "/a", at: 250, in: layout, strip) == .amongGroupTabs(0))
        #expect(placement(of: "/a", at: 300, in: layout, strip) == .amongGroupTabs(1))
        #expect(placement(of: "/a", at: 440, in: layout, strip) == .amongGroupTabs(2))
        #expect(placement(of: "/c", at: 100, in: layout, strip) == .asNewGroup(0))
        #expect(placement(of: "/c", at: 450, in: layout, strip) == .asNewGroup(1))
        #expect(placement(of: "/c", at: 760, in: layout, strip) == .asNewGroup(2))
    }

    /// Placed where the bar's drag then keeps it, a tab arriving among its group's tabs slides none of them aside.
    @Test func anArrivingTabStaysWhereTheBarsDragWouldPutIt() throws {
        let layout = makeLayout()
        let strip = makeStrip()
        let groupUnits = strip.movingUnits(inGroup: "/a")
        let unitWidths = try groupUnits.map { try #require(layout.span(ofTabs: $0, inGroup: "/a")).width }
        let rowLeadingEdge = try #require(layout.span(ofTabs: groupUnits[0], inGroup: "/a")).minX
        let arrivingTabID = tabID(4)
        let arrivingTabWidth: CGFloat = 120

        for tabsLeadingEdge in stride(from: CGFloat(150), through: 650, by: 5) {
            guard case .amongGroupTabs(let place) = placement(of: "/a", at: tabsLeadingEdge, in: layout, strip) else {
                Issue.record("A tab of a group in the bar joins its group")
                return
            }
            var itemIDs = groupUnits
            itemIDs.insert([arrivingTabID], at: place)
            var widths = unitWidths
            widths.insert(arrivingTabWidth, at: place)
            var barDrag = try #require(TabBarDrag(dragging: [arrivingTabID], among: itemIDs, widths: widths, spacing: 0))
            barDrag.translation = tabsLeadingEdge - rowLeadingEdge - widths.prefix(place).reduce(0, +)
            #expect(barDrag.targetIndex == place, "leading edge at \(tabsLeadingEdge)")
        }
    }

    // MARK: - Holding the tabs under the pointer

    @Test func theTabsStayUnderThePointerWhereTheyWereGrabbed() {
        let grab = TabDragGrab(distanceFromTabsLeadingEdge: 30, depthBelowWindowTop: 18)

        #expect(grab.translation(pointerX: 500, tabsLeadingEdge: 340) == 130)
        let origin = grab.carrierWindowOrigin(pointer: CGPoint(x: 700, y: 900), tabsLeadingEdge: 280, windowHeight: 600)
        #expect(origin == CGPoint(x: 390, y: 318))
    }

    // MARK: - Helpers

    private static let tabIDs = (0..<5).map { _ in UUID() }

    private func tabID(_ index: Int) -> UUID { Self.tabIDs[index] }

    /// Tab 0 in group `/a`, then tabs 1 and 2 in a split; tab 3 in group `/b`.
    private func makeStrip() -> TerminalTabStrip {
        TerminalTabStrip(tabs: [
            TerminalTabStrip.Tab(id: tabID(0), projectKey: "/a"),
            TerminalTabStrip.Tab(id: tabID(1), projectKey: "/a"),
            TerminalTabStrip.Tab(id: tabID(2), projectKey: "/a"),
            TerminalTabStrip.Tab(id: tabID(3), projectKey: "/b"),
        ], splits: [TerminalSplit(tabIDs: (tabID(1), tabID(2)), groupKey: "/a")])
    }

    /// For tabs whose group's label is 40 points wide.
    private func placement(
        of groupKey: String,
        at tabsLeadingEdge: CGFloat,
        in layout: TabBarLayout,
        _ strip: TerminalTabStrip
    ) -> TabStripPlacement {
        layout.placement(forTabsOfGroup: groupKey, leadingEdgeAt: tabsLeadingEdge, tabsDistanceFromGroupLeadingEdge: 40, in: strip)
    }

    /// Group `/a` from 200, its label 40 wide, then a 100-point tab and a split of two 100-point tabs; group `/b` 14
    /// points after it, from 554, its label 40 wide, then one 200-point tab.
    private func makeLayout() -> TabBarLayout {
        TabBarLayout(
            groupSpans: [
                "/a": TabBarLayout.Span(minX: 200, width: 340),
                "/b": TabBarLayout.Span(minX: 554, width: 240),
            ],
            tabSpansInGroups: [
                tabID(0): TabBarLayout.Span(minX: 40, width: 100),
                tabID(1): TabBarLayout.Span(minX: 140, width: 100),
                tabID(2): TabBarLayout.Span(minX: 240, width: 100),
                tabID(3): TabBarLayout.Span(minX: 40, width: 200),
            ]
        )
    }
}
