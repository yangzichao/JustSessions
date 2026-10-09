/// A tab, or a split's two tabs, on its way from one window to another, its terminal and CLI still running.
struct TabsBetweenWindows {
    let unit: DetachedTabStripUnit
    /// The unit's tabs, in its order.
    let tabs: [TerminalSession]
}
