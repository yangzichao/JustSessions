import Foundation

extension ConversationStore {
    /// Claude Code writes a new transcript before the first prompt, so a freshly listed session can still be untitled.
    static let maximumTitleRefreshesPerNewSession = 3
    static let refreshIntervalWhileWaitingForAppearingSession: TimeInterval = 6

    var pendingNewSessions: [PendingNewSession] {
        terminalSessions.compactMap(\.pendingNewSession)
    }

    func startNewSessionDiscovery(interval: Duration = .seconds(2)) {
        runPeriodically(every: interval) { await $0.discoverNewSessions(mayRefresh: true) }
    }

    func discoverNewSessions(mayRefresh: Bool, finder: NewSessionFileFinder = NewSessionFileFinder()) async {
        guard !isScanningThisMac, !isDeletingSessions else { return }
        if mayRefresh, let untitledTab = terminalSessions.first(where: { needsRefreshForFirstPromptTitle($0) }) {
            untitledTab.titleRefreshCount += 1
            refreshThisMac()
            return
        }
        if mayRefresh, isWaitingForAppearingSessionOnThisMac, isDueForRefreshWhileWaitingForAppearingSession {
            refreshThisMac()
            return
        }

        let waitingTabs = terminalSessions.filter {
            $0.isNewSessionAwaitingConversation && $0.host == .thisMac && !$0.isWaitingForAppearingSession
        }
        guard !waitingTabs.isEmpty else { return }
        let searches = waitingTabs.compactMap(\.waitingNewSessionTab)
        let sessionFiles = await Task.detached(priority: .utility) {
            finder.sessionFiles(for: searches, processTree: .ofRunningProcesses())
        }.value

        var hasUnlistedSessionFile = false
        for tab in waitingTabs {
            guard let sessionFile = sessionFiles[tab.id],
                !linkWaitingNewSessionTab(tab, toSessionID: sessionFile.sessionID)
            else { continue }
            if wasModifiedSinceLastRefresh(sessionFile.lastModified) { hasUnlistedSessionFile = true }
        }
        if mayRefresh && hasUnlistedSessionFile { refreshThisMac() }
    }

    @discardableResult
    func linkWaitingNewSessionTab(_ session: TerminalSession, toSessionID sessionID: String) -> Bool {
        guard session.isNewSessionAwaitingConversation,
            let conversation = conversations.first(where: {
                $0.provider == session.provider && $0.sessionID == sessionID
            })
        else { return false }
        link(session, to: conversation)
        return true
    }

    private func needsRefreshForFirstPromptTitle(_ session: TerminalSession) -> Bool {
        guard !session.hasExited, session.host == .thisMac,
            session.titleRefreshCount < Self.maximumTitleRefreshesPerNewSession,
            let conversation = session.conversation, conversation.isAwaitingFirstPromptTitle
        else { return false }
        // A SQLite source, such as OpenCode's, writes to its `-wal` file first.
        return wasModifiedSinceLastRefresh(
            max(
                ConversationMetadata.fileModificationDate(conversation.sourceFile),
                ConversationMetadata.fileModificationDate(URL(fileURLWithPath: conversation.sourceFile.path + "-wal"))
            ))
    }

    private var isWaitingForAppearingSessionOnThisMac: Bool {
        terminalSessions.contains { $0.host == .thisMac && $0.isWaitingForAppearingSession && !$0.hasExited }
    }

    private var isDueForRefreshWhileWaitingForAppearingSession: Bool {
        guard let lastRefreshStartedAt else { return true }
        return Date.now.timeIntervalSince(lastRefreshStartedAt) >= Self.refreshIntervalWhileWaitingForAppearingSession
    }

    private func wasModifiedSinceLastRefresh(_ modificationDate: Date) -> Bool {
        guard let lastRefreshStartedAt else { return true }
        return modificationDate > lastRefreshStartedAt
    }
}
