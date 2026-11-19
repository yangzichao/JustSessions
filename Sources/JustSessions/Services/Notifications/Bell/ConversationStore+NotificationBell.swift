import Foundation

extension ConversationStore {
    func noteWaitingForYouStartTimes(after observations: [SessionActivityObservation], at now: Date = .now) {
        var next = waitingForYouStartTimes
        next.update(after: observations, unseenFinishedTurns: unseenFinishedTurns, at: now)
        guard next != waitingForYouStartTimes else { return }
        waitingForYouStartTimes = next
    }

    var notificationBellEntries: [NotificationBellEntry] {
        let tabEntries = ([self] + otherWindowStores).flatMap { store in
            let terminalIDsOnScreen = store.terminalIDsOnScreen
            return store.terminalSessions.compactMap { tab in
                terminalIDsOnScreen.contains(tab.id) ? nil : store.notificationBellEntry(for: tab)
            }
        }
        let conversationIDsWithRunningTab = Set(
            ([self] + otherWindowStores).flatMap { store in
                store.terminalSessions.filter(\.isRunning).compactMap { $0.conversation?.id }
            })
        let detachedEntries = detachedCLIActivities.keys
            .filter { !conversationIDsWithRunningTab.contains($0) }
            .compactMap(notificationBellEntry(forDetachedConversationID:))
        return (tabEntries + detachedEntries).sortedNewestFirst()
    }

    func showSession(fromNotificationBell entry: NotificationBellEntry) {
        windowRegistry.showSession(wantingAttention: entry.source, reattachingIn: self)
    }

    private func notificationBellEntry(for tab: TerminalSession) -> NotificationBellEntry? {
        guard tab.isRunning, let provider = tab.provider,
            let reason = WaitingForYou.reason(
                activity: tab.cliActivity,
                hasUnseenFinishedTurn: tab.hasUnseenFinishedTurn
            )
        else { return nil }
        return NotificationBellEntry(
            source: tab.attentionSource,
            reason: reason,
            waitingSince: waitingForYouStartTimes.startTime(of: tab.attentionSource),
            sessionTitle: tab.displayTitle,
            provider: provider,
            projectName: projectDisplayName(forProjectPath: tab.projectDirectoryKey)
        )
    }

    private func notificationBellEntry(forDetachedConversationID conversationID: String) -> NotificationBellEntry? {
        guard let conversation = conversation(withID: conversationID),
            !hiddenConversationProviders.hides(conversation.provider),
            let reason = WaitingForYou.reason(
                activity: detachedCLIActivities[conversationID],
                hasUnseenFinishedTurn: hasUnseenFinishedTurn(detachedConversationID: conversationID)
            )
        else { return nil }
        let source = SessionAttentionSource.detachedTmux(conversationID: conversationID)
        return NotificationBellEntry(
            source: source,
            reason: reason,
            waitingSince: waitingForYouStartTimes.startTime(of: source),
            sessionTitle: title(for: conversation),
            provider: conversation.provider,
            projectName: projectDisplayName(forProjectPath: conversation.projectDirectoryKey)
        )
    }
}
