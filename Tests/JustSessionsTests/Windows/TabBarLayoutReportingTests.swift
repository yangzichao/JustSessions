import Foundation
import SwiftUI
import Testing

@testable import JustSessions

/// A tab that moves to another section of the tab bar, as a split across projects becomes a split of one project's
/// tabs, keeps the span its new place reports: the view it leaves takes out only what it reported itself. Without its
/// span, the tab could no longer be dragged off the bar.
@MainActor
struct TabBarLayoutReportingTests {
    private static let barWidth: CGFloat = 900

    @Test func tabsLeavingASplitAcrossProjectsKeepTheSpansOfTheirNewPlaces() async throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let first = open(store, makeTab(projectPath: "/tmp/app"))
        let second = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(tools.id)
        store.splitSelectedTerminal(with: first.id)
        let splitAcrossProjects = try #require(store.shownSplit)
        try #require(splitAcrossProjects.spansProjects)
        let fixture = makeFixture(store: store)
        defer { fixture.close() }
        _ = try await fixture.capture(named: "tab-bar-before-split-joins-one-project")

        // The second app tab takes the tools tab's place, so the split holds one project's tabs: both of its tabs
        // and the tools tab now show in their projects' groups.
        let toolsSide = try #require(store.sides(of: splitAcrossProjects)?.side(of: tools.id))
        store.moveIntoShownSplit(second.id, swappingWith: toolsSide)
        let split = try #require(store.shownSplit)
        try #require(!split.spansProjects)
        _ = try await fixture.capture(named: "tab-bar-after-split-joins-one-project")

        let layout = TabDragBetweenWindows.shared.layouts.layout(of: store)
        #expect(layout.span(ofTabs: [tools.id], inGroup: tools.projectDirectoryKey) != nil)
        #expect(layout.span(ofTabs: [first.id, second.id], inGroup: first.projectDirectoryKey) != nil)
        #expect(layout.groupSpans[splitAcrossProjects.groupKey] == nil)
    }

    // MARK: - Helpers

    private func makeFixture(store: ConversationStore) -> ThemeSurfaceRenderingFixture {
        let bar = WorkspaceTabBar(
            store: store, leadingClearance: 0, onRenameConversation: { _ in }, onNewSession: {},
            onCloseTerminal: { _ in }, onDeleteConversation: { _ in }, onCloseTabGroup: { _, _ in }
        )
        .frame(width: Self.barWidth)
        return ThemeSurfaceRenderingFixture(
            content: AnyView(bar),
            size: CGSize(width: Self.barWidth, height: WorkspaceTabMetrics.topInset + WorkspaceTabMetrics.height),
            colorScheme: .light
        )
    }

    private func makeStore() throws -> (ConversationStore, () -> Void) {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        return (
            store,
            {
                store.closeAllTerminals()
                isolatedUserDefaults.removeSuite()
            }
        )
    }

    private func open(_ store: ConversationStore, _ tab: TerminalSession) -> TerminalSession {
        store.openTerminal(tab)
        return tab
    }

    private func makeTab(projectPath: String) -> TerminalSession {
        TerminalSession(
            engine: .swiftTerm,
            conversation: nil,
            provider: .claude,
            projectPath: projectPath,
            action: .resume,
            displayTitle: "Tab in \(projectPath)",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
    }
}
