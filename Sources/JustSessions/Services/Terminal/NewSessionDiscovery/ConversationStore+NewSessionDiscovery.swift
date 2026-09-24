import Foundation

/// A tab started with "new session" has no conversation until the CLI writes its transcript.
/// While such a tab is open, this notices the transcript and refreshes, so the session shows up
/// under its project without waiting for the tab to be closed or switched away from, and then
/// links the tab to that conversation.
extension ConversationStore {
    func startNewSessionDiscovery(interval: Duration = .seconds(2)) {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                self.associateOpenClaudeSessions()
                await self.refreshWhenNewSessionTranscriptAppears()
            }
        }
    }

    func refreshWhenNewSessionTranscriptAppears(
        registry: ClaudeLiveSessionRegistry = ClaudeLiveSessionRegistry(),
        claudeLocator: ClaudeSessionFileLocator = ClaudeSessionFileLocator()
    ) async {
        guard !isLoading, !isDeletingSessions else { return }
        let waitingSessions = terminalSessions.filter {
            $0.action == .new && $0.conversation == nil && !$0.hasExited && $0.processID > 0
        }
        guard !waitingSessions.isEmpty else { return }

        let knownClaudeSessionIDs = Set(conversations.filter { $0.provider == .claude }.map(\.sessionID))
        let hasUnlistedClaudeSession = waitingSessions.contains { session in
            guard session.provider == .claude,
                  let record = registry.record(forProcessID: session.processID),
                  !knownClaudeSessionIDs.contains(record.sessionID) else { return false }
            return claudeLocator.transcriptExists(forSessionID: record.sessionID)
        }
        if hasUnlistedClaudeSession {
            refresh()
            return
        }

        let codexProcessIDs = waitingSessions.filter { $0.provider == .codex }.map(\.processID)
        guard !codexProcessIDs.isEmpty else { return }
        let openCodexFiles = await Task.detached(priority: .utility) {
            let locator = CodexSessionFileLocator()
            return codexProcessIDs.compactMap { locator.openSessionFile(for: $0)?.path }
        }.value
        let knownCodexFiles = Set(conversations.map { $0.sourceFile.standardizedFileURL.path })
        if openCodexFiles.contains(where: { !knownCodexFiles.contains($0) }) { refresh() }
    }

    /// Links each new Claude Code tab to its conversation once the sidebar knows it, using the session id
    /// Claude Code records for the tab's process.
    func associateOpenClaudeSessions(registry: ClaudeLiveSessionRegistry = ClaudeLiveSessionRegistry()) {
        var linkedAnySession = false
        for session in terminalSessions where session.provider == .claude && session.action == .new
            && session.conversation == nil && session.processID > 0 {
            guard let record = registry.record(forProcessID: session.processID) else { continue }
            if linkNewSession(session, toClaudeRecord: record) { linkedAnySession = true }
        }
        // Sidebar rows look up open terminals through the store, which does not see a tab's own changes.
        if linkedAnySession { objectWillChange.send() }
    }

    @discardableResult
    func linkNewSession(_ session: TerminalSession, toClaudeRecord record: ClaudeLiveSessionRecord) -> Bool {
        guard let conversation = conversations.first(where: {
            $0.provider == .claude && $0.sessionID == record.sessionID
        }) else { return false }
        session.synchronize(conversation: conversation, displayTitle: title(for: conversation))
        return true
    }
}
