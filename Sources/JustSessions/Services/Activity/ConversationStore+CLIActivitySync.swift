import Foundation

/// Once a second, reads what each CLI on this Mac is doing: every tab's, and every session's whose CLI runs in tmux
/// with no tab open. A session whose CLI ended in tmux stops counting as running then, without waiting for a refresh.
/// A CLI that just finished its turn or stopped to wait on you gets a notification, and one that finished its turn
/// out of view stays marked until you look.
extension ConversationStore {
    /// A session on this Mac whose CLI runs in tmux with no tab open.
    private struct DetachedTmuxSession {
        let conversation: Conversation
        let tmuxSessionName: String
        /// Unknown when the tab it ran in closed before its process was found.
        let paneProcessID: Int32?
    }

    func startCLIActivitySync(interval: Duration = .seconds(1)) {
        runPeriodically(every: interval) { await $0.synchronizeCLIActivity() }
    }

    func synchronizeCLIActivity(
        claudeRegistry: ClaudeLiveSessionRegistry = ClaudeLiveSessionRegistry(),
        liveSessionReporting: LiveSessionReporting? = .thisApp
    ) async {
        let probedTabs = terminalSessions.compactMap { tab in
            tab.isRunning ? tab.cliActivityProbe.map { (tab: tab, probe: $0) } : nil
        }
        let detachedSessions = detachedThisMacTmuxSessions()
        guard !probedTabs.isEmpty || !detachedSessions.isEmpty || !detachedCLIActivities.isEmpty else {
            followAttention(after: [])
            return
        }

        let probes = probedTabs.map(\.probe) + detachedSessions.map {
            CLIActivityProbe(provider: $0.conversation.provider, processID: $0.paneProcessID ?? 0, sessionFile: $0.conversation.sourceFile)
        }
        let paneProcessIDs = detachedSessions.map(\.paneProcessID)
        let reader = CLIActivityReader(
            claudeRegistry: claudeRegistry,
            codexTurnTracker: codexTurnTracker,
            liveSessionReporting: liveSessionReporting
        )
        let (activities, endedPanes) = await Task.detached(priority: .utility) {
            (
                reader.activities(for: probes),
                paneProcessIDs.map { processID in processID.map { !RunningProcessInfo.isRunning($0) } ?? false }
            )
        }.value

        var hasTabActivityChanged = false
        for (index, probedTab) in probedTabs.enumerated() where probedTab.tab.updateCLIActivity(activities[index]) {
            hasTabActivityChanged = true
        }
        var observations = probedTabs.enumerated().map { index, probedTab in
            SessionActivityObservation(source: probedTab.tab.attentionSource, activity: activities[index])
        }
        var detachedActivities: [String: CLIActivity] = [:]
        for (index, detachedSession) in detachedSessions.enumerated() {
            // tmux ends a session once its only pane's process exits.
            if endedPanes[index] {
                tmuxSessionNamesByHost[.thisMac]?.remove(detachedSession.tmuxSessionName)
                thisMacTmuxPaneProcessIDs[detachedSession.tmuxSessionName] = nil
                continue
            }
            let activity = activities[probedTabs.count + index]
            observations.append(SessionActivityObservation(
                source: .detachedTmux(conversationID: detachedSession.conversation.id),
                activity: activity
            ))
            if let activity { detachedActivities[detachedSession.conversation.id] = activity }
        }
        if detachedCLIActivities != detachedActivities { detachedCLIActivities = detachedActivities }
        followAttention(after: observations)
        // Project rows sum up their tabs through the store, which does not see a tab's own changes.
        if hasTabActivityChanged { objectWillChange.send() }
    }

    private func followAttention(after observations: [SessionActivityObservation]) {
        let events = sessionAttentionTracker.events(after: observations)
        notifyOfSessionsWantingAttention(events)
        noteUnseenFinishedTurns(after: observations, events: events)
    }

    /// Listed sessions of this Mac that run in tmux, as of the last refresh, with no running tab.
    private func detachedThisMacTmuxSessions() -> [DetachedTmuxSession] {
        guard let runningNames = tmuxSessionNamesByHost[.thisMac], !runningNames.isEmpty else { return [] }
        let conversationIDsWithRunningTab = Set(terminalSessions.filter(\.isRunning).compactMap { $0.conversation?.id })
        return runningNames.sorted().compactMap { name in
            guard let session = TmuxSessionName.session(named: name),
                  let conversation = conversations.first(where: {
                      $0.host == .thisMac && $0.provider == session.provider && $0.sessionID == session.sessionID
                  }),
                  !conversationIDsWithRunningTab.contains(conversation.id) else { return nil }
            return DetachedTmuxSession(
                conversation: conversation,
                tmuxSessionName: name,
                paneProcessID: thisMacTmuxPaneProcessIDs[name]
            )
        }
    }
}
