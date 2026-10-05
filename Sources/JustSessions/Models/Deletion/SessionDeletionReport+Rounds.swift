import Foundation

/// A deletion that sessions joined while it ran deletes them in a later round; its rounds make one report.
extension SessionDeletionReport {
    /// This report and the next round's as one, canceled when the next round was.
    func followed(by nextRound: SessionDeletionReport) -> SessionDeletionReport {
        SessionDeletionReport(
            requestedCount: requestedCount + nextRound.requestedCount,
            deletedCount: deletedCount + nextRound.deletedCount,
            failures: failures + nextRound.failures,
            wasCanceled: nextRound.wasCanceled
        )
    }

    /// The SSH hosts given up on, by host, so a later round does not try them again.
    var unresponsiveHosts: [String: UnresponsiveSSHHost] {
        var unresponsiveHosts: [String: UnresponsiveSSHHost] = [:]
        for unresponsiveHost in failures.compactMap(\.unresponsiveHost) where unresponsiveHosts[unresponsiveHost.host] == nil {
            unresponsiveHosts[unresponsiveHost.host] = unresponsiveHost
        }
        return unresponsiveHosts
    }
}
