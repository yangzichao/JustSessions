import Foundation

/// A tab, a split's two tabs, or a whole group's tabs on their way from one window to another, their terminals and
/// CLIs still running.
struct TabsBetweenWindows {
    let unit: DetachedTabStripUnit
    /// The unit's tabs, in its order.
    let tabs: [TerminalSession]
    /// The unit's splits whose views are stacked, which stay stacked in the other window (SPL-18).
    var stackedSplitIDs: Set<UUID> = []
}
