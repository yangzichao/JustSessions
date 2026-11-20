import Foundation

@MainActor
enum UnlistedClaudeSessionRefreshPolicy {
    static let failedCopiesBeforeWaitingLonger = 3

    static func shouldRefreshThisMac(
        for unlisted: UnlistedClaudeSession,
        transcriptModificationDate: () -> Date,
        now: Date
    ) -> Bool {
        guard let requestedAt = unlisted.refreshRequestedAt else { return true }
        let waitedLongEnough =
            now.timeIntervalSince(requestedAt) >= ConversationStore.refreshIntervalWhileWaitingForAppearingSession
        return waitedLongEnough && transcriptModificationDate() > requestedAt
    }

    static func shouldCopyRemoteHost(
        for unlisted: UnlistedClaudeSession,
        copies: RemoteHostCopies.Copies,
        terminalTitle: String?,
        now: Date
    ) -> Bool {
        guard let endOfCopyThatMissedTheSession = endOfCopyStartedSinceTheMove(copies, movedAt: unlisted.movedAt)
        else { return true }
        guard now.timeIntervalSince(endOfCopyThatMissedTheSession) >= waitBeforeCopyingAgain(after: copies) else {
            return false
        }
        let lastCopySucceeded = copies.failuresInARow == 0
        let relayTitleChangedSinceRequest = terminalTitle != unlisted.terminalTitleAtRequest
        return !lastCopySucceeded || relayTitleChangedSinceRequest
    }

    static func waitBeforeCopyingAgain(after copies: RemoteHostCopies.Copies) -> TimeInterval {
        guard copies.failuresInARow >= failedCopiesBeforeWaitingLonger else {
            return ConversationStore.refreshIntervalWhileWaitingForRemoteSession
        }
        return HostAutoRefreshSchedule.wait(afterFailuresInARow: copies.failuresInARow - failedCopiesBeforeWaitingLonger + 1)
    }

    private static func endOfCopyStartedSinceTheMove(_ copies: RemoteHostCopies.Copies, movedAt: Date) -> Date? {
        guard let startedAt = copies.lastStartedAt, startedAt >= movedAt else { return nil }
        return copies.lastEndedAt
    }
}
