import Testing

@testable import JustSessions

struct SidebarSearchScopeTests {
    @Test func savedScopeNamesStayTheSame() {
        #expect(SidebarSearchScope.allCases.map(\.rawValue) == ["everything", "namesOnly"])
    }

    @Test func namesOnlyLeavesMessagesAndBookmarksUnsearched() {
        #expect(SidebarSearchScope.everything.searchesMessagesAndBookmarks)
        #expect(SidebarSearchScope.everything.messageSearchQuery(typedQuery: "deploy") == "deploy")
        #expect(!SidebarSearchScope.namesOnly.searchesMessagesAndBookmarks)
        #expect(SidebarSearchScope.namesOnly.messageSearchQuery(typedQuery: "deploy").isEmpty)
    }
}
