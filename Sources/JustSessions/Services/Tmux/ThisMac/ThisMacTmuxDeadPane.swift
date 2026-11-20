import Foundation

struct ThisMacTmuxDeadPane {
    let exitCode: Int32?

    static let titlePrefix = "justsessions-exited:"
    private static let deadPaneTitle = "\(titlePrefix)#{pane_dead_status}"
    private static let livePaneTitle = "#{pane_title}"
    static let terminalTitleFormat = "#{?pane_dead,\(deadPaneTitle),\(livePaneTitle)}"

    init?(terminalTitle: String) {
        guard terminalTitle.hasPrefix(Self.titlePrefix) else { return nil }
        exitCode = Int32(terminalTitle.dropFirst(Self.titlePrefix.count))
    }
}
