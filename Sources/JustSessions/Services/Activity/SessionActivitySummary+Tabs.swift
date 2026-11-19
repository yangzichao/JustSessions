import Foundation

extension SessionActivitySummary {
    @MainActor
    init(tabs: [TerminalSession]) {
        self.init(statuses: tabs.filter { !$0.isPlainTerminal && $0.isRunning }.map(\.runStatus))
    }
}
