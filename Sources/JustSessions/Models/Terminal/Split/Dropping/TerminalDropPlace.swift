/// Where a tab or session dragged onto a window's terminals shows once let go.
enum TerminalDropPlace: Equatable {
    /// On this side of a split view laid out this way: the half of a new split beside the selected tab, or the shown
    /// split's pane, whose orientation it then has.
    case split(TerminalSplit.Side, TerminalSplit.Orientation)
    /// Filling the terminals on its own: in place of the shown tab, which stays open behind it, or as the window shows
    /// no tab to split with.
    case wholeArea
}
