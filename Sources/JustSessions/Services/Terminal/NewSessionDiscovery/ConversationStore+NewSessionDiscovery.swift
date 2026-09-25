import Foundation

/// A tab started with "New session" or "Branch" has no conversation until the CLI writes its session file;
/// a branch runs a fork with an id of its own. The sidebar lists such a tab under its project right away
/// (`pendingNewSessions`). Meanwhile this finds the file the tab's CLI is writing, refreshes so the real
/// session shows up, and links the tab to it.
extension ConversationStore {
    /// Claude Code writes a new transcript before the first prompt, so a freshly listed session can still be
    /// untitled. This many refreshes after its file changes are enough to pick up the first prompt.
    static let maximumTitleRefreshesPerNewSession = 3

    var pendingNewSessions: [PendingNewSession] {
        terminalSessions.compactMap(\.pendingNewSession)
    }

    func startNewSessionDiscovery(interval: Duration = .seconds(2)) {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                await self.discoverNewSessions(mayRefresh: true)
            }
        }
    }

    /// Links waiting tabs to their conversations. With `mayRefresh` it also refreshes when a tab's session
    /// file changed since the last refresh started. Only the periodic pass passes it, so these refreshes
    /// happen at most once per interval.
    func discoverNewSessions(mayRefresh: Bool, finder: NewSessionFileFinder = NewSessionFileFinder()) async {
        guard !isScanningThisMac, !isDeletingSessions else { return }
        if mayRefresh, let untitledTab = terminalSessions.first(where: { needsRefreshForFirstPromptTitle($0) }) {
            untitledTab.titleRefreshCount += 1
            refreshThisMac()
            return
        }

        // Tabs on SSH hosts run `ssh`, whose open files say nothing; see `linkWaitingRemoteNewSessionTabs`.
        let waitingTabs = terminalSessions.filter { $0.isNewSessionAwaitingConversation && $0.host == .thisMac }
        guard !waitingTabs.isEmpty else { return }
        let searches = waitingTabs.map(\.waitingNewSessionTab)
        let sessionFiles = await Task.detached(priority: .utility) {
            finder.sessionFiles(for: searches, processTree: .ofRunningProcesses())
        }.value

        var hasUnlistedSessionFile = false
        for tab in waitingTabs {
            guard let sessionFile = sessionFiles[tab.id],
                  !linkWaitingNewSessionTab(tab, toSessionID: sessionFile.sessionID) else { continue }
            if wasModifiedSinceLastRefresh(sessionFile.lastModified) { hasUnlistedSessionFile = true }
        }
        if mayRefresh && hasUnlistedSessionFile { refreshThisMac() }
    }

    @discardableResult
    func linkWaitingNewSessionTab(_ session: TerminalSession, toSessionID sessionID: String) -> Bool {
        guard session.isNewSessionAwaitingConversation,
              let conversation = conversations.first(where: {
                  $0.provider == session.provider && $0.sessionID == sessionID
              }) else { return false }
        session.synchronize(conversation: conversation, displayTitle: title(for: conversation))
        // Sidebar rows look up open terminals through the store, which does not see a tab's own changes.
        objectWillChange.send()
        return true
    }

    private func needsRefreshForFirstPromptTitle(_ session: TerminalSession) -> Bool {
        guard session.action.startsNewSession, !session.hasExited, session.host == .thisMac,
              session.titleRefreshCount < Self.maximumTitleRefreshesPerNewSession,
              let conversation = session.conversation,
              conversation.suggestedTitle == ConversationMetadata.untitledConversationTitle else { return false }
        return wasModifiedSinceLastRefresh(ConversationMetadata.fileModificationDate(conversation.sourceFile))
    }

    /// A refresh already saw every change made before it started, so only later changes are worth another.
    private func wasModifiedSinceLastRefresh(_ modificationDate: Date) -> Bool {
        guard let lastRefreshStartedAt else { return true }
        return modificationDate > lastRefreshStartedAt
    }
}
