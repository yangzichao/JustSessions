import Foundation

/// A Codex tab follows the thread its CLI is in, as the terminal title names it; see `CodexThreadTitle`. A new
/// session's tab links to its thread, and a tab whose CLI moved to another thread, as with `/new` or `/resume`, shows
/// that one from then on, the way a Claude Code tab follows `/clear`. Only tabs on this Mac start Codex that way.
extension ConversationStore {
    func startCodexThreadFollowing(interval: Duration = .seconds(1)) {
        runPeriodically(every: interval) { await $0.followCodexThreads() }
    }

    /// A thread no refresh listed yet gets one refresh of this Mac once its rollout file is saved, and the tab links
    /// to it once a refresh lists it.
    func followCodexThreads(locator: CodexRolloutLocator = CodexRolloutLocator()) async {
        guard !isScanningThisMac, !isDeletingSessions else { return }
        var unlistedThreads: [(tab: TerminalSession, threadIDPrefix: String)] = []
        for session in terminalSessions where session.provider == .codex && session.host == .thisMac && !session.hasExited {
            guard let threadIDPrefix = session.terminalTitle.flatMap(CodexThreadTitle.threadIDPrefix(inTerminalTitle:)),
                  session.conversation?.sessionID.hasPrefix(threadIDPrefix) != true else { continue }
            if let thread = listedCodexThread(on: session.host, threadIDPrefix: threadIDPrefix) {
                link(session, to: thread)
            } else {
                unlistedThreads.append((session, threadIDPrefix))
            }
        }
        guard !unlistedThreads.isEmpty else { return }

        // A thread `/new` starts gets its rollout file with the first prompt; until then there is nothing to list.
        let threadIDPrefixes = unlistedThreads.map(\.threadIDPrefix)
        let earliestStart = lastRefreshStartedAt
        let savedSessionIDs = await Task.detached(priority: .utility) {
            threadIDPrefixes.map { locator.sessionID(forThreadIDPrefix: $0, startedOnOrAfter: earliestStart) }
        }.value
        var hasThreadToList = false
        for (unlistedThread, savedSessionID) in zip(unlistedThreads, savedSessionIDs) {
            guard let savedSessionID, unlistedThread.tab.cliSessionIDRefreshedFor != savedSessionID else { continue }
            unlistedThread.tab.cliSessionIDRefreshedFor = savedSessionID
            hasThreadToList = true
        }
        if hasThreadToList { refreshThisMac() }
    }

    /// Nil unless the id of exactly one listed Codex session starts with `threadIDPrefix`.
    private func listedCodexThread(on host: SessionHost, threadIDPrefix: String) -> Conversation? {
        let matches = conversations.filter {
            $0.provider == .codex && $0.host == host && $0.sessionID.hasPrefix(threadIDPrefix)
        }
        return matches.count == 1 ? matches.first : nil
    }
}
