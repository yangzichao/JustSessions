import SwiftUI

extension View {
    /// Reports where the group lays out in its window to `TabDragBetweenWindows`. Applied after the group's offset, so
    /// a drag shifting it changes nothing.
    func reportsTabBarGroupSpan(_ groupKey: String, in store: ConversationStore) -> some View {
        modifier(TabBarSpanReporting(item: .group(groupKey), store: store))
    }

    /// The coordinate space of a group's tabs, from its leading edge; see `reportsTabSpanInGroup(_:in:)`.
    func tabBarGroupCoordinateSpace() -> some View {
        coordinateSpace(.named(TabBarLayout.groupCoordinateSpace))
    }

    /// Reports where the tab lays out in its group to `TabDragBetweenWindows`. Applied after the tab's offset, so a
    /// drag shifting it changes nothing.
    func reportsTabSpanInGroup(_ tabID: UUID, in store: ConversationStore) -> some View {
        modifier(TabBarSpanReporting(item: .tab(tabID), store: store))
    }
}

/// Reports the view's span as it lays out, a group's in the window and a tab's from its group's leading edge, and takes
/// it out as the view goes, unless a view that took the group's or tab's place has reported it since.
private struct TabBarSpanReporting: ViewModifier {
    let item: TabBarLayouts.Item
    let store: ConversationStore

    @State private var reporter = UUID()

    func body(content: Content) -> some View {
        // The geometry closure is Sendable, so it takes a copy of the item.
        let item = item
        return
            content
            .onGeometryChange(for: TabBarLayout.Span.self) { proxy in
                let frame =
                    switch item {
                    case .group: proxy.frame(in: .global)
                    case .tab: proxy.frame(in: .named(TabBarLayout.groupCoordinateSpace))
                    }
                return TabBarLayout.Span(minX: frame.minX, width: frame.width)
            } action: { span in
                TabDragBetweenWindows.shared.layouts.report(span, of: item, in: store, by: reporter)
            }
            .onDisappear { TabDragBetweenWindows.shared.layouts.withdraw(item, in: store, by: reporter) }
    }
}
