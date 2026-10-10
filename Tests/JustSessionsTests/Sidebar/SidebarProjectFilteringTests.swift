import Foundation
import Testing
@testable import JustSessions

struct SidebarProjectFilteringTests {
    @Test func providerFilterOrdersProjectsByTheirRemainingSessions() {
        let olderClaude = Conversation.fixture(provider: .claude, projectPath: "/work/first", updatedAt: Date(timeIntervalSince1970: 10))
        let newestCodex = Conversation.fixture(provider: .codex, projectPath: "/work/first", updatedAt: Date(timeIntervalSince1970: 30))
        let newerClaude = Conversation.fixture(provider: .claude, projectPath: "/work/second", updatedAt: Date(timeIntervalSince1970: 20))
        let projects = ProjectConversationGroup.grouped([olderClaude, newestCodex, newerClaude])

        let filteredProjects = SidebarProjectFiltering.projects(projects, providerFilter: .only(.claude), recencyFilter: .all)

        #expect(projects.map(\.id) == [olderClaude.projectDirectoryKey, newerClaude.projectDirectoryKey])
        #expect(filteredProjects.map(\.id) == [newerClaude.projectDirectoryKey, olderClaude.projectDirectoryKey])
    }

    @Test func filtersRetainEmptyProjectsWithoutShowingFilteredOutSessionsAsEmptyProjects() {
        let oldClaude = Conversation.fixture(provider: .claude, projectPath: "/work/old", updatedAt: .distantPast)
        let recentCodex = Conversation.fixture(provider: .codex, projectPath: "/work/recent")
        let projects = ProjectConversationGroup.grouped(
            [oldClaude, recentCodex],
            retainedProjectPaths: ["/work/empty", oldClaude.projectDirectoryKey, recentCodex.projectDirectoryKey]
        )

        let filteredProjects = SidebarProjectFiltering.projects(projects, providerFilter: .only(.claude), recencyFilter: .recent)
        #expect(filteredProjects.map(\.id) == ["/work/empty"])
        #expect(filteredProjects.first?.sessionCount == 0)
        #expect(SidebarProjectFiltering.projects(filteredProjects, matching: "empty", title: \.suggestedTitle).count == 1)
        #expect(SidebarProjectFiltering.projects(filteredProjects, matching: "missing", title: \.suggestedTitle).isEmpty)
        let allRecentProjects = SidebarProjectFiltering.projects(projects, providerFilter: .all, recencyFilter: .recent)
        #expect(allRecentProjects.map(\.id) == [recentCodex.projectDirectoryKey, "/work/empty"])
    }

    @Test func waitingForYouKeepsOnlyWaitingSessionsAndNewSessionTabsAndDropsEmptyProjects() {
        let waiting = Conversation.fixture(provider: .claude, projectPath: "/work/app")
        let quiet = Conversation.fixture(provider: .claude, projectPath: "/work/app")
        let otherQuiet = Conversation.fixture(provider: .codex, projectPath: "/work/site")
        let waitingNewSession = PendingNewSession(
            terminalID: UUID(), provider: .codex, projectDirectoryKey: "/work/site", title: "New session", startedAt: .now
        )
        let quietNewSession = PendingNewSession(
            terminalID: UUID(), provider: .codex, projectDirectoryKey: "/work/site", title: "New session", startedAt: .now
        )
        let projects = ProjectConversationGroup.grouped(
            [waiting, quiet, otherQuiet],
            pendingNewSessions: [waitingNewSession, quietNewSession],
            retainedProjectPaths: ["/work/empty", "/work/app", "/work/site"]
        )
        let waitingSessions = SessionsWaitingForYou(conversationIDs: [waiting.id], terminalIDs: [waitingNewSession.terminalID])

        let filtered = SidebarProjectFiltering.projects(
            projects,
            providerFilter: .all,
            recencyFilter: .all,
            statusFilter: .waitingForYou,
            waiting: waitingSessions
        )

        #expect(Set(filtered.map(\.id)) == ["/work/app", "/work/site"])
        #expect(filtered.flatMap(\.conversations).map(\.id) == [waiting.id])
        #expect(filtered.flatMap(\.pendingNewSessions).map(\.id) == [waitingNewSession.id])
        let unfiltered = SidebarProjectFiltering.projects(projects, providerFilter: .all, recencyFilter: .all, waiting: waitingSessions)
        #expect(unfiltered.contains { $0.id == "/work/empty" })
        #expect(unfiltered.flatMap(\.conversations).count == 3)
    }

    @Test func runningKeepsOnlySessionsWhoseCLIRunsAndRunningNewSessionTabsAndDropsEmptyProjects() {
        let running = Conversation.fixture(provider: .claude, projectPath: "/work/app")
        let ended = Conversation.fixture(provider: .claude, projectPath: "/work/app")
        let runningOnDevbox = Conversation.fixture(provider: .codex, projectPath: "/work/site", host: .ssh("devbox"))
        let runningNewSession = PendingNewSession(
            terminalID: UUID(), provider: .codex, projectDirectoryKey: runningOnDevbox.projectDirectoryKey, title: "New session", startedAt: .now
        )
        let endedNewSession = PendingNewSession(
            terminalID: UUID(), provider: .codex, projectDirectoryKey: runningOnDevbox.projectDirectoryKey, title: "New session", startedAt: .now
        )
        let projects = ProjectConversationGroup.grouped(
            [running, ended, runningOnDevbox],
            pendingNewSessions: [runningNewSession, endedNewSession],
            retainedProjectPaths: ["/work/empty", "/work/app", runningOnDevbox.projectDirectoryKey]
        )
        let runningSessions = SessionsRunning(
            conversationIDs: [running.id, runningOnDevbox.id], terminalIDs: [runningNewSession.terminalID]
        )

        let filtered = SidebarProjectFiltering.projects(
            projects,
            providerFilter: .all,
            recencyFilter: .all,
            statusFilter: .running,
            running: runningSessions
        )

        #expect(Set(filtered.map(\.id)) == ["/work/app", runningOnDevbox.projectDirectoryKey])
        #expect(Set(filtered.flatMap(\.conversations).map(\.id)) == [running.id, runningOnDevbox.id])
        #expect(filtered.flatMap(\.pendingNewSessions).map(\.id) == [runningNewSession.id])
        // A session that runs but does not wait on you is not listed by Waiting for you.
        let waitingOnly = SidebarProjectFiltering.projects(
            projects, providerFilter: .all, recencyFilter: .all, statusFilter: .waitingForYou, running: runningSessions
        )
        #expect(waitingOnly.isEmpty)
    }

    @Test func projectMatchKeepsAllSessionsAndSessionMatchKeepsOnlyMatches() {
        let website = conversation(project: "/tmp/website", title: "Fix header")
        let websiteOther = conversation(project: "/tmp/website", title: "Update footer")
        let api = conversation(project: "/tmp/api", title: "Fix auth bug")
        let apiOther = conversation(project: "/tmp/api", title: "Add logging")
        let projects = ProjectConversationGroup.grouped([website, websiteOther, api, apiOther])
        let title: (Conversation) -> String = \.suggestedTitle

        let websiteMatch = SidebarProjectFiltering.projects(projects, matching: "websi", title: title)
        #expect(websiteMatch.map { $0.conversations.count } == [2])

        let fixMatch = SidebarProjectFiltering.projects(projects, matching: " fix ", title: title)
        #expect(Set(fixMatch.flatMap(\.conversations).map(\.id)) == [website.id, api.id])

        #expect(SidebarProjectFiltering.projects(projects, matching: "", title: title).count == 2)
        #expect(SidebarProjectFiltering.projects(projects, matching: "nothing", title: title).isEmpty)
    }

    @Test func sessionsWhoseMessagesMatchStayAlongWithTitleMatches() {
        let titleMatch = conversation(project: "/tmp/api", title: "Fix the cache key")
        let messageMatch = conversation(project: "/tmp/api", title: "Refactor storage")
        let noMatch = conversation(project: "/tmp/api", title: "Add logging")
        let otherProjectMessageMatch = conversation(project: "/tmp/website", title: "Header")
        let projects = ProjectConversationGroup.grouped([titleMatch, messageMatch, noMatch, otherProjectMessageMatch])

        let filtered = SidebarProjectFiltering.projects(
            projects, matching: "cache key", title: \.suggestedTitle,
            messageMatchConversationIDs: [messageMatch.id, otherProjectMessageMatch.id]
        )

        #expect(Set(filtered.flatMap(\.conversations).map(\.id)) == [titleMatch.id, messageMatch.id, otherProjectMessageMatch.id])
        #expect(filtered.count == 2)
    }

    @Test func newSessionsAwaitingTheirConversationFollowTheSameRules() {
        let website = conversation(project: "/tmp/website", title: "Fix header")
        let newSession = PendingNewSession(
            terminalID: UUID(),
            provider: .claude,
            projectDirectoryKey: website.projectDirectoryKey,
            title: "New Claude Code session",
            startedAt: .now
        )
        let projects = ProjectConversationGroup.grouped([website], pendingNewSessions: [newSession])
        let title: (Conversation) -> String = \.suggestedTitle

        #expect(SidebarProjectFiltering.projects(projects, matching: "websi", title: title).first?.pendingNewSessions == [newSession])
        let newSessionMatch = SidebarProjectFiltering.projects(projects, matching: "new claude", title: title)
        #expect(newSessionMatch.first?.pendingNewSessions == [newSession])
        #expect(newSessionMatch.first?.conversations.isEmpty == true)
        #expect(SidebarProjectFiltering.projects(projects, matching: "header", title: title).first?.pendingNewSessions.isEmpty == true)
    }

    private func conversation(project: String, title: String) -> Conversation {
        let sessionID = UUID().uuidString
        return Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: project,
            suggestedTitle: title,
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl")
        )
    }
}
