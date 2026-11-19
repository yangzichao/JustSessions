import Observation

/// A drag along the tab bar as the bar draws it, see `TabBarDrag`, observed property by property: the views that lay
/// out the row read `placement`, which changes only as the drag starts or ends, or as the dragged item passes another,
/// and each item's shift reads `drag`, which changes with every move of the pointer. So a move re-runs only the
/// shifts, not the tabs, their groups, or the bar; see `tabBarDragShift(of:in:)`.
@MainActor
@Observable
final class TabBarDragDisplay<ItemID: Hashable> {
    /// The drag as it last placed the items, or nil while none shows.
    private(set) var placement: TabBarDrag<ItemID>?
    /// The drag as the pointer has moved it, or nil while none shows.
    private(set) var drag: TabBarDrag<ItemID>?

    /// Shows the drag, or none for nil, changing only what differs.
    func show(_ nextDrag: TabBarDrag<ItemID>?) {
        if drag != nextDrag { drag = nextDrag }
        let placesItemsAlike =
            switch (placement, nextDrag) {
            case (nil, nil): true
            case (let placement?, let nextDrag?): placement.placesItemsAlike(nextDrag)
            default: false
            }
        if !placesItemsAlike { placement = nextDrag }
    }
}
