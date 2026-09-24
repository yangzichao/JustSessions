import Foundation
import Testing
@testable import JustSessions

struct SidebarProjectFilteringTests {
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
