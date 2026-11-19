import CoreGraphics
import Foundation

struct TabBarLayout: Equatable {
    static let groupCoordinateSpace = "TabBarGroup"

    struct Span: Equatable, Sendable {
        var minX: CGFloat
        var width: CGFloat

        var midX: CGFloat { minX + width / 2 }
    }

    var groupSpans: [String: Span] = [:]
    var tabSpansInGroups: [UUID: Span] = [:]

    var isEmpty: Bool { groupSpans.isEmpty && tabSpansInGroups.isEmpty }

    func span(ofTabs tabIDs: [UUID], inGroup groupKey: String) -> Span? {
        guard let groupSpan = groupSpans[groupKey] else { return nil }
        let tabSpans = tabIDs.compactMap { tabSpansInGroups[$0] }
        guard tabSpans.count == tabIDs.count, let leadingEdge = tabSpans.map(\.minX).min() else { return nil }
        return Span(minX: groupSpan.minX + leadingEdge, width: tabSpans.map(\.width).reduce(0, +))
    }

    var groupsLeadingEdge: CGFloat? {
        groupSpans.values.map(\.minX).min()
    }

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
