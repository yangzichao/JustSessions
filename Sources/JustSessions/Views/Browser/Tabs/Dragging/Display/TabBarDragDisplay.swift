import Observation

@MainActor
@Observable
final class TabBarDragDisplay<ItemID: Hashable> {
    private(set) var placement: TabBarDrag<ItemID>?
    private(set) var drag: TabBarDrag<ItemID>?

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
