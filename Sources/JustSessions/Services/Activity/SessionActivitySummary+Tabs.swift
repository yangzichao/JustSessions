import Foundation

extension SessionActivitySummary {
    /// What these tabs' CLIs are doing, for a collapsed tab group. A plain terminal runs no session, so it does not count.
    @MainActor
    init(tabs: [TerminalSession]) {
        self.init(activities: tabs.filter { !$0.isPlainTerminal && $0.isRunning }.map(\.cliActivity))
    }
}
