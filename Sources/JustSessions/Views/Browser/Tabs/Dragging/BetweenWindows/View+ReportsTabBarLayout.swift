import SwiftUI

extension View {
    /// Reports where the group lays out in its window to `TabDragBetweenWindows`. Applied after the group's offset, so
    /// a drag shifting it changes nothing.
    func reportsTabBarGroupSpan(_ groupKey: String, in store: ConversationStore) -> some View {
        onGeometryChange(for: TabBarLayout.Span.self) { proxy in
            let frame = proxy.frame(in: .global)
            return TabBarLayout.Span(minX: frame.minX, width: frame.width)
        } action: { span in
            TabDragBetweenWindows.shared.layouts.report(span, ofGroup: groupKey, in: store)
        }
        .onDisappear { TabDragBetweenWindows.shared.layouts.report(nil, ofGroup: groupKey, in: store) }
    }

    /// The coordinate space of a group's tabs, from its leading edge; see `reportsTabSpanInGroup(_:in:)`.
    func tabBarGroupCoordinateSpace() -> some View {
        coordinateSpace(.named(TabBarLayout.groupCoordinateSpace))
    }

    /// Reports where the tab lays out in its group to `TabDragBetweenWindows`. Applied after the tab's offset, so a
    /// drag shifting it changes nothing.
    func reportsTabSpanInGroup(_ tabID: UUID, in store: ConversationStore) -> some View {
        onGeometryChange(for: TabBarLayout.Span.self) { proxy in
            let frame = proxy.frame(in: .named(TabBarLayout.groupCoordinateSpace))
            return TabBarLayout.Span(minX: frame.minX, width: frame.width)
        } action: { span in
            TabDragBetweenWindows.shared.layouts.report(span, ofTab: tabID, in: store)
        }
        .onDisappear { TabDragBetweenWindows.shared.layouts.report(nil, ofTab: tabID, in: store) }
    }
}
