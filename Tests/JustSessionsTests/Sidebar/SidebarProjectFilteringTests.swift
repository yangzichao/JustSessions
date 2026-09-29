import Foundation
import Testing
@testable import JustSessions

struct SidebarProjectFilteringTests {
    @Test func providerFilterOrdersProjectsByTheirRemainingSessions() {
        let olderClaude = Conversation.fixture(provider: .claude, projectPath: "/work/first", updatedAt: Date(timeIntervalSince1970: 10))
        let newestCodex = Conversation.fixture(provider: .codex, projectPath: "/work/first", updatedAt: Date(timeIntervalSince1970: 30))
        let newerClaude = Conversation.fixture(provider: .claude, projectPath: "/work/second", updatedAt: Date(timeIntervalSince1970: 20))
        let projects = ProjectConversationGroup.grouped([olderClaude, newestCodex, newerClaude])

        let filteredProjects = SidebarProjectFiltering.projects(projects, providerFilter: .claude, recencyFilter: .all)

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

        let filteredProjects = SidebarProjectFiltering.projects(projects, providerFilter: .claude, recencyFilter: .recent)
        #expect(filteredProjects.map(\.id) == ["/work/empty"])
        #expect(filteredProjects.first?.sessionCount == 0)
        #expect(SidebarProjectFiltering.projects(filteredProjects, matching: "empty", title: \.suggestedTitle).count == 1)
        #expect(SidebarProjectFiltering.projects(filteredProjects, matching: "missing", title: \.suggestedTitle).isEmpty)
        let allRecentProjects = SidebarProjectFiltering.projects(projects, providerFilter: .all, recencyFilter: .recent)
        #expect(allRecentProjects.map(\.id) == [recentCodex.projectDirectoryKey, "/work/empty"])
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
