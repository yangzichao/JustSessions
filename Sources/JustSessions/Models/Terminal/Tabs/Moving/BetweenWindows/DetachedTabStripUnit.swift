import Foundation

/// A tab, or a split's two tabs, taken out of one window's tab bar to go into another's. A split goes whole, so its
/// panes stay side by side.
struct DetachedTabStripUnit: Equatable {
    /// In tab bar order, so a split's left pane's tab comes first.
    let tabs: [TerminalTabStrip.Tab]
    /// The split linking the two tabs, when they are a split's.
    let split: TerminalSplit?
    /// The group the tabs show in once in another window's tab bar: their split's, while one of them is of the split's
    /// project, or else their first tab's project.
    let groupKey: String
}
