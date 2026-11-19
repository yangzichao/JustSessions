import SwiftUI

extension View {
    func reportsTabBarGroupSpan(_ groupKey: String, in store: ConversationStore) -> some View {
        modifier(TabBarSpanReporting(item: .group(groupKey), store: store))
    }

    func tabBarGroupCoordinateSpace() -> some View {
        coordinateSpace(.named(TabBarLayout.groupCoordinateSpace))
    }

    func reportsTabSpanInGroup(_ tabID: UUID, in store: ConversationStore) -> some View {
        modifier(TabBarSpanReporting(item: .tab(tabID), store: store))
    }
}

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
