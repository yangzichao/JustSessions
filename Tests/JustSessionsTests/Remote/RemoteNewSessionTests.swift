import Foundation
import Testing
@testable import JustSessions

struct RemoteNewSessionTests {
    @Test func tabTakesTheFirstNewSessionInItsProjectOnly() {
        let known = remoteConversation(.claude, project: "/home/me/paper", minutesAgo: 30)
        let otherProject = remoteConversation(.claude, project: "/home/me/api", minutesAgo: 1)
        let otherTool = remoteConversation(.codex, project: "/home/me/paper", minutesAgo: 1)
        let otherHost = remoteConversation(.claude, project: "/home/me/paper", minutesAgo: 1, host: "laptop")
        let newer = remoteConversation(.claude, project: "/home/me/paper", minutesAgo: 1)
        let newest = remoteConversation(.claude, project: "/home/me/paper", minutesAgo: 0)
        let first = waitingTab(project: "/home/me/paper", known: [known.sessionID], startedMinutesAgo: 5)
        let second = waitingTab(project: "/home/me/paper", known: [known.sessionID], startedMinutesAgo: 2)

        let matches = RemoteNewSessionMatcher.matches(
            for: [second, first],
            in: [known, otherProject, otherTool, otherHost, newest, newer],
            alreadyLinkedConversationIDs: []
        )

        #expect(matches[first.terminalID]?.id == newer.id)
        #expect(matches[second.terminalID]?.id == newest.id)
    }

    @Test func sessionLinkedToAnotherTabIsNotReused() {
        let linked = remoteConversation(.codex, project: "/home/me/api", minutesAgo: 1)
        let tab = WaitingRemoteNewSessionTab(
            terminalID: UUID(),
            host: "devbox",
            provider: .codex,
            projectPath: "/home/me/api",
            launchedAt: .now,
            sessionIDsKnownAtLaunch: []
        )
        let matches = RemoteNewSessionMatcher.matches(for: [tab], in: [linked], alreadyLinkedConversationIDs: [linked.id])
        #expect(matches.isEmpty)
    }

    @Test @MainActor func newSessionInRemoteProjectOpensOverSSHAndLinksOnceListed() throws {
        let store = ConversationStore(adapters: [])
        let existing = remoteConversation(.claude, project: "/home/me/paper", minutesAgo: 60)
        store.replaceConversations(on: .ssh("devbox"), with: [existing])

        store.launchNewSessionFromProject(
            provider: .claude,
            projectPath: ProjectLocation(host: .ssh("devbox"), path: "/home/me/paper").key
        )
        let tab = try #require(store.terminalSessions.last)
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.command.executablePath == "/usr/bin/ssh")
        #expect(tab.command.arguments.last?.contains("exec claude") == true)
        #expect(tab.pendingNewSession?.projectDirectoryKey == "ssh://devbox/home/me/paper")

        store.linkWaitingRemoteNewSessionTabs(onHost: "devbox")
        #expect(tab.conversation == nil)

        let created = remoteConversation(.claude, project: "/home/me/paper", minutesAgo: 0)
        store.replaceConversations(on: .ssh("devbox"), with: [existing, created])
        store.linkWaitingRemoteNewSessionTabs(onHost: "devbox")
        #expect(tab.conversation?.id == created.id)
        store.closeAllTerminals()
    }

    @Test @MainActor func branchInRemoteProjectWaitsForItsForkNotTheSessionItForked() throws {
        let store = ConversationStore(adapters: [StaticConversationAdapter(discoveredConversations: [])])
        let forked = remoteConversation(.claude, project: "/home/me/paper", minutesAgo: 60)
        store.replaceConversations(on: .ssh("devbox"), with: [forked])

        store.launch(forked, action: .branch)
        let tab = try #require(store.terminalSessions.last)
        #expect(tab.command.executablePath == "/usr/bin/ssh")
        #expect(tab.conversation == nil)
        #expect(tab.pendingNewSession?.projectDirectoryKey == "ssh://devbox/home/me/paper")

        let fork = remoteConversation(.claude, project: "/home/me/paper", minutesAgo: 0)
        let matches = RemoteNewSessionMatcher.matches(
            for: [tab.waitingRemoteNewSessionTab],
            in: [forked, fork],
            alreadyLinkedConversationIDs: []
        )
        #expect(matches[tab.id]?.id == fork.id)
        store.closeAllTerminals()
    }

    private func remoteConversation(
        _ provider: ConversationProvider,
        project: String,
        minutesAgo: Double,
        host: String = "devbox"
    ) -> Conversation {
        let sessionID = UUID().uuidString
        return Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: project,
            suggestedTitle: sessionID,
            updatedAt: Date(timeIntervalSinceNow: -minutesAgo * 60),
            sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl"),
            host: .ssh(host)
        )
    }

    private func waitingTab(project: String, known: Set<String>, startedMinutesAgo: Double) -> WaitingRemoteNewSessionTab {
        WaitingRemoteNewSessionTab(
            terminalID: UUID(),
            host: "devbox",
            provider: .claude,
            projectPath: project,
            launchedAt: Date(timeIntervalSinceNow: -startedMinutesAgo * 60),
            sessionIDsKnownAtLaunch: known
        )
    }
}
