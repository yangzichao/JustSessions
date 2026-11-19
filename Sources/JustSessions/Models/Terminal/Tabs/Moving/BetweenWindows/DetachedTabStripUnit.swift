import Foundation

struct DetachedTabStripUnit: Equatable {
    let tabs: [TerminalTabStrip.Tab]
    let splits: [TerminalSplit]
    let groupKey: String
}
