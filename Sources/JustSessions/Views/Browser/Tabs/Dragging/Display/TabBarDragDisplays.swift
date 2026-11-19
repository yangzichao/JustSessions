import Foundation
import Observation

@MainActor
@Observable
final class TabBarDragDisplays {
    @ObservationIgnored let amongGroups = TabBarDragDisplay<String>()
    var leavingTabIDs: Set<UUID> = []
    @ObservationIgnored private var amongTabsByGroupKey: [String: TabBarDragDisplay<[UUID]>] = [:]

    func amongTabs(ofGroup groupKey: String) -> TabBarDragDisplay<[UUID]> {
        if let display = amongTabsByGroupKey[groupKey] { return display }
        let display = TabBarDragDisplay<[UUID]>()
        amongTabsByGroupKey[groupKey] = display
        return display
    }
}
