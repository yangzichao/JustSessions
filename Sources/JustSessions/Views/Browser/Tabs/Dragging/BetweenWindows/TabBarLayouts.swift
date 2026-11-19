import Foundation

@MainActor
final class TabBarLayouts {
    enum Item: Hashable, Sendable {
        case group(String)
        case tab(UUID)
    }

    private var layoutsByStore: [ObjectIdentifier: TabBarLayout] = [:]
    private var reportersByStore: [ObjectIdentifier: [Item: UUID]] = [:]
    var onChange: ((ConversationStore) -> Void)?

    func layout(of store: ConversationStore) -> TabBarLayout {
        layoutsByStore[ObjectIdentifier(store)] ?? TabBarLayout()
    }

    func report(_ span: TabBarLayout.Span, of item: Item, in store: ConversationStore, by reporter: UUID) {
        reportersByStore[ObjectIdentifier(store), default: [:]][item] = reporter
        change(item, to: span, in: store)
    }

    func withdraw(_ item: Item, in store: ConversationStore, by reporter: UUID) {
        let storeID = ObjectIdentifier(store)
        guard reportersByStore[storeID]?[item] == reporter else { return }
        reportersByStore[storeID]?[item] = nil
        if reportersByStore[storeID]?.isEmpty == true { reportersByStore[storeID] = nil }
        change(item, to: nil, in: store)
    }

    private func change(_ item: Item, to span: TabBarLayout.Span?, in store: ConversationStore) {
        let storeID = ObjectIdentifier(store)
        var layout = layoutsByStore[storeID] ?? TabBarLayout()
        switch item {
        case .group(let groupKey): layout.groupSpans[groupKey] = span
        case .tab(let tabID): layout.tabSpansInGroups[tabID] = span
        }
        guard layout != layoutsByStore[storeID] ?? TabBarLayout() else { return }
        layoutsByStore[storeID] = layout.isEmpty ? nil : layout
        onChange?(store)
    }
}
