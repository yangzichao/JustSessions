import Foundation

/// Every window's `TabBarLayout`, by its store, as its tab bar reports it. A tab bar takes out each group and tab that
/// leaves it, so a closed window leaves nothing behind.
@MainActor
final class TabBarLayouts {
    private var layoutsByStore: [ObjectIdentifier: TabBarLayout] = [:]
    /// Called after a window's tab bar lays out anew.
    var onChange: ((ConversationStore) -> Void)?

    func layout(of store: ConversationStore) -> TabBarLayout {
        layoutsByStore[ObjectIdentifier(store)] ?? TabBarLayout()
    }

    func report(_ span: TabBarLayout.Span?, ofGroup groupKey: String, in store: ConversationStore) {
        change(store) { $0.groupSpans[groupKey] = span }
    }

    func report(_ span: TabBarLayout.Span?, ofTab tabID: UUID, in store: ConversationStore) {
        change(store) { $0.tabSpansInGroups[tabID] = span }
    }

    private func change(_ store: ConversationStore, _ update: (inout TabBarLayout) -> Void) {
        let storeID = ObjectIdentifier(store)
        var layout = layoutsByStore[storeID] ?? TabBarLayout()
        update(&layout)
        guard layout != layoutsByStore[storeID] ?? TabBarLayout() else { return }
        layoutsByStore[storeID] = layout.isEmpty ? nil : layout
        onChange?(store)
    }
}
