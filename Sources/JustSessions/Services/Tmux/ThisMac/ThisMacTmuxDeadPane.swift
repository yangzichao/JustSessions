import Foundation

struct ThisMacTmuxDeadPane {
    let exitCode: Int32?

    static let titlePrefix = "justsessions-exited:"
    static let titleFormat = "#{?pane_dead,\(titlePrefix)#{pane_dead_status},#{pane_title}}"

    init?(terminalTitle: String) {
        guard terminalTitle.hasPrefix(Self.titlePrefix) else { return nil }
        exitCode = Int32(terminalTitle.dropFirst(Self.titlePrefix.count))
    }
}
