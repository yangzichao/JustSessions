import Foundation

extension ConversationStore {
    private struct DetachedTmuxSession {
        let conversation: Conversation
        let tmuxSessionName: String
        let paneProcessID: Int32?
    }

    private struct DetachedRemoteTmuxSession {
        let conversation: Conversation
        let key: RemoteTmuxSessionKey
    }

    func startCLIActivitySync(interval: Duration = .seconds(1)) {
        runPeriodically(every: interval) { await $0.synchronizeCLIActivity() }
    }

    func synchronizeCLIActivity(
        claudeRegistry: ClaudeLiveSessionRegistry = ClaudeLiveSessionRegistry(),
        liveSessionReporting: LiveSessionReporting? = .ofThePackagedApp
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

    private func conversationIDsWithRunningTab() -> Set<String> {
        Set(terminalSessions.filter(\.isRunning).compactMap { $0.conversation?.id })
            .union(runningTerminalsInOtherWindows.keys)
    }

    private func listedSession(inTmuxSessionNamed name: String, on host: SessionHost) -> Conversation? {
        guard let session = TmuxSessionName.session(named: name) else { return nil }
        return conversationIndex.conversation(withID: Conversation.id(provider: session.provider, sessionID: session.sessionID, host: host))
    }

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

    private func askHosts(of sessions: [DetachedRemoteTmuxSession]) {
        for host in Set(sessions.map(\.key.host)) where !sshHostsNeedingLogIn.contains(host) && !isDisconnected(host) {
            remoteDetachedActivityReader.askIfDue(host)
        }
    }

    private func noteRemoteSessionsDetached(_ sessions: [DetachedRemoteTmuxSession]) {
        let keys = Set(sessions.map(\.key))
        let now = remoteDetachedActivityReader.now
        remoteDetachedSince = remoteDetachedSince.filter { keys.contains($0.key) }
        for key in keys where remoteDetachedSince[key] == nil { remoteDetachedSince[key] = now }
    }

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
