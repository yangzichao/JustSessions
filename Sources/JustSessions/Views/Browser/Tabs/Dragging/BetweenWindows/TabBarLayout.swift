import CoreGraphics
import Foundation

/// Where a window's tab bar lays out its groups and tabs, along the bar, before any drag shifts one: each group's span
/// in the window, and each tab's within its group, whose leading edge is its label's. A tab dragged in from another
/// window follows the pointer from these, and a window carrying a dragged tab keeps the tab under the pointer.
struct TabBarLayout: Equatable {
    /// The name of the coordinate space a group's tabs are measured in, the group's own.
    static let groupCoordinateSpace = "TabBarGroup"

    struct Span: Equatable, Sendable {
        var minX: CGFloat
        var width: CGFloat

        var midX: CGFloat { minX + width / 2 }
    }

    /// By group key, in window coordinates.
    var groupSpans: [String: Span] = [:]
    /// By tab id, from the leading edge of the tab's group.
    var tabSpansInGroups: [UUID: Span] = [:]

    var isEmpty: Bool { groupSpans.isEmpty && tabSpansInGroups.isEmpty }

    /// The tabs' span together in the window, such as a split's two, once the bar has laid them out in `groupKey`.
    func span(ofTabs tabIDs: [UUID], inGroup groupKey: String) -> Span? {
        guard let groupSpan = groupSpans[groupKey] else { return nil }
        let tabSpans = tabIDs.compactMap { tabSpansInGroups[$0] }
        guard tabSpans.count == tabIDs.count, let leadingEdge = tabSpans.map(\.minX).min() else { return nil }
        return Span(minX: groupSpan.minX + leadingEdge, width: tabSpans.map(\.width).reduce(0, +))
    }

    /// The first group's leading edge.
    var groupsLeadingEdge: CGFloat? {
        groupSpans.values.map(\.minX).min()
    }

    /// Where tabs of `groupKey` dragged in with their leading edge at `tabsLeadingEdge`, in window coordinates, go in
    /// `strip`, this bar's: where the bar's drag then keeps them (see `TabBarDrag.targetIndex`), so nothing slides as
    /// they arrive. That is among their group's tabs and splits, past each whose middle is before the tabs' leading
    /// edge, or with none of their group here, as a new group past each group whose middle is before the new group's
    /// leading edge, `tabsDistanceFromGroupLeadingEdge` before the tabs'. Tabs or groups not laid out, such as a
    /// collapsed group's tabs, count as before.
    func placement(
        forTabsOfGroup groupKey: String,
        leadingEdgeAt tabsLeadingEdge: CGFloat,
        tabsDistanceFromGroupLeadingEdge: CGFloat,
        in strip: TerminalTabStrip
    ) -> TabStripPlacement {
        let groupKeys = strip.groupKeysInOrder
        guard groupKeys.contains(groupKey) else {
            let groupLeadingEdge = tabsLeadingEdge - tabsDistanceFromGroupLeadingEdge
            return .asNewGroup(groupKeys.filter { groupSpans[$0].map { $0.midX <= groupLeadingEdge } ?? true }.count)
        }
        let units = strip.movingUnits(inGroup: groupKey)
        return .amongGroupTabs(units.filter { span(ofTabs: $0, inGroup: groupKey).map { $0.midX <= tabsLeadingEdge } ?? true }.count)
    }
}
