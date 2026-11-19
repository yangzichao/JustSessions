import Foundation

extension SessionDeletionReport {
    func followed(by nextRound: SessionDeletionReport) -> SessionDeletionReport {
        SessionDeletionReport(
            requestedCount: requestedCount + nextRound.requestedCount,
            deletedCount: deletedCount + nextRound.deletedCount,
            failures: failures + nextRound.failures,
            wasCanceled: nextRound.wasCanceled
        )
    }

    var unresponsiveHosts: [String: UnresponsiveSSHHost] {
        var unresponsiveHosts: [String: UnresponsiveSSHHost] = [:]
        for unresponsiveHost in failures.compactMap(\.unresponsiveHost) where unresponsiveHosts[unresponsiveHost.host] == nil {
            unresponsiveHosts[unresponsiveHost.host] = unresponsiveHost
        }
        return unresponsiveHosts
    }
}
