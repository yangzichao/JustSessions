import Foundation

/// Once a second, reads what each CLI on this Mac is doing: every tab's, and every session's whose CLI runs in tmux
/// with no tab open. A Codex, Claude Code, Pi, or OpenCode tab on an SSH host tells through its terminal title; see
/// `CodexTitleActivity` and `RemoteCLIActivityTitle`. Such a session on an SSH host with no tab open is read from its
/// host every few seconds instead; see `RemoteDetachedActivityReader`. A session whose CLI ended in tmux stops counting
/// as running then, without waiting for a refresh. A CLI that just finished its turn or stopped to wait on you gets a
/// notification, and one that finished its turn out of view stays marked until you look.
extension ConversationStore {
    /// A session on this Mac whose CLI runs in tmux with no tab open.
    private struct DetachedTmuxSession {
        let conversation: Conversation
        let tmuxSessionName: String
        /// Unknown when the tab it ran in closed before its process was found.
        let paneProcessID: Int32?
    }

    /// A session on an SSH host whose CLI runs in tmux with no tab open in any window.
    private struct DetachedRemoteTmuxSession {
        let conversation: Conversation
        let key: RemoteTmuxSessionKey
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
        let conversationIDsWithRunningTab = conversationIDsWithRunningTab()
        let detachedSessions = detachedThisMacTmuxSessions(conversationIDsWithRunningTab: conversationIDsWithRunningTab)
        let detachedRemoteSessions = detachedRemoteTmuxSessions(conversationIDsWithRunningTab: conversationIDsWithRunningTab)
        noteRemoteSessionsDetached(detachedRemoteSessions)
        askHosts(of: detachedRemoteSessions)
        guard
            !probedTabs.isEmpty || !detachedSessions.isEmpty || !detachedRemoteSessions.isEmpty
                || !detachedCLIActivities.isEmpty
        else {
            followAttention(after: [])
            return
        }

        let probes =
            probedTabs.map(\.probe)
            + detachedSessions.map {
                CLIActivityProbe(
                    provider: $0.conversation.provider,
                    processID: $0.paneProcessID ?? 0,
                    sessionFile: $0.conversation.sourceFile,
                    sessionID: $0.conversation.sessionID
                )
            }
        let paneProcessIDs = detachedSessions.map(\.paneProcessID)
        let reader = CLIActivityReader(
            claudeRegistry: claudeRegistry,
            codexTurnTracker: codexTurnTracker,
            liveSessionReporting: liveSessionReporting,
            codexWaitReader: codexWaitReader
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
            observations.append(
                SessionActivityObservation(
                    source: .detachedTmux(conversationID: detachedSession.conversation.id),
                    activity: activity
                ))
            if let activity { detachedActivities[detachedSession.conversation.id] = activity }
        }
        for detachedSession in detachedRemoteSessions {
            let key = detachedSession.key
            let listing = remoteDetachedActivityReader.listing(of: key.host)
            // A listing asked for after the session was known to run with no tab, which leaves it out: its CLI ended.
            if let listing, listing.panes.panesBySessionName[key.tmuxSessionName] == nil,
                let since = remoteDetachedSince[key], listing.askedAt > since
            {
                tmuxSessionNamesByHost[.ssh(key.host)]?.remove(key.tmuxSessionName)
                remoteDetachedSince[key] = nil
                continue
            }
            let activity = listing?.panes.activity(of: detachedSession.conversation.provider, inSession: key.tmuxSessionName)
            observations.append(
                SessionActivityObservation(
                    source: .detachedTmux(conversationID: detachedSession.conversation.id),
                    activity: activity
                ))
            if let activity { detachedActivities[detachedSession.conversation.id] = activity }
        }
        if detachedCLIActivities != detachedActivities { detachedCLIActivities = detachedActivities }
        followAttention(after: observations)
        // Project rows sum up their tabs through the store, which does not see a tab's own changes. Other windows'
        // rows show these tabs' CLIs too.
        if hasTabActivityChanged {
            noteTabStateChanged()
            windowRegistry.tabsChanged(in: self)
        }
    }

    private func followAttention(after observations: [SessionActivityObservation]) {
        let events = sessionAttentionTracker.events(after: observations)
        notifyOfSessionsWantingAttention(events)
        noteUnseenFinishedTurns(after: observations, events: events)
        noteWaitingForYouStartTimes(after: observations)
    }

    /// The sessions shown by a running tab in this window or another.
    private func conversationIDsWithRunningTab() -> Set<String> {
        Set(terminalSessions.filter(\.isRunning).compactMap { $0.conversation?.id })
            .union(runningTerminalsInOtherWindows.keys)
    }

    /// The listed session a tmux session of the app's runs, found through the index: this runs once a second for every
    /// tmux session on every host, and going through every listed session for each took 30 ms a second with 3,365
    /// sessions listed and 58 running (PERF-88).
    private func listedSession(inTmuxSessionNamed name: String, on host: SessionHost) -> Conversation? {
        guard let session = TmuxSessionName.session(named: name) else { return nil }
        return conversationIndex.conversation(withID: Conversation.id(provider: session.provider, sessionID: session.sessionID, host: host))
    }

    /// Listed sessions of SSH hosts that run in tmux, as of the host's last refresh or the closing of their tab, with no
    /// running tab in any window.
    private func detachedRemoteTmuxSessions(conversationIDsWithRunningTab: Set<String>) -> [DetachedRemoteTmuxSession] {
        var sessions: [DetachedRemoteTmuxSession] = []
        for (sessionHost, runningNames) in tmuxSessionNamesByHost {
            guard let host = sessionHost.sshDestination else { continue }
            for name in runningNames.sorted() {
                guard let conversation = listedSession(inTmuxSessionNamed: name, on: sessionHost),
                    !conversationIDsWithRunningTab.contains(conversation.id)
                else { continue }
                let key = RemoteTmuxSessionKey(host: host, tmuxSessionName: name)
                sessions.append(DetachedRemoteTmuxSession(conversation: conversation, key: key))
            }
        }
        return sessions
    }

    /// Asks the hosts of these sessions what their CLIs do, except one that needs Connect…, which no background command
    /// reaches, and one you disconnected from. Each is asked only when due; see `RemoteDetachedActivityReader`.
    private func askHosts(of sessions: [DetachedRemoteTmuxSession]) {
        for host in Set(sessions.map(\.key.host)) where !sshHostsNeedingLogIn.contains(host) && !isDisconnected(host) {
            remoteDetachedActivityReader.askIfDue(host)
        }
    }

    /// Keeps when each such session was first seen with no tab, and forgets the others.
    private func noteRemoteSessionsDetached(_ sessions: [DetachedRemoteTmuxSession]) {
        let keys = Set(sessions.map(\.key))
        // By the reader's clock, which its listings' times are taken by.
        let now = remoteDetachedActivityReader.now
        remoteDetachedSince = remoteDetachedSince.filter { keys.contains($0.key) }
        for key in keys where remoteDetachedSince[key] == nil { remoteDetachedSince[key] = now }
    }

    /// Listed sessions of this Mac that run in tmux, as of the last refresh, with no running tab in any window. The
    /// window whose tab runs one follows what its CLI does and notifies about it.
    private func detachedThisMacTmuxSessions(conversationIDsWithRunningTab: Set<String>) -> [DetachedTmuxSession] {
        guard let runningNames = tmuxSessionNamesByHost[.thisMac], !runningNames.isEmpty else { return [] }
        return runningNames.sorted().compactMap { name in
            guard let conversation = listedSession(inTmuxSessionNamed: name, on: .thisMac),
                !conversationIDsWithRunningTab.contains(conversation.id)
            else { return nil }
            return DetachedTmuxSession(
                conversation: conversation,
                tmuxSessionName: name,
                paneProcessID: thisMacTmuxPaneProcessIDs[name]
            )
        }
    }
}
