/// Where tabs from another window go in a tab bar: among their group's tabs when the bar has their group, or else as a
/// new group among the groups. Each place is counted as `TerminalTabStrip+Moving` counts them.
enum TabStripPlacement: Equatable {
    /// At the place among the group's tabs and splits.
    case amongGroupTabs(Int)
    /// At the place among the groups.
    case asNewGroup(Int)
}
