import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// Subagents' sessions stay out of the sidebar until Settings → General turns them on, even under a session that was
/// expanded while they showed.
@MainActor
struct SidebarSubagentVisibilityTests {
    @Test func anExpandedSessionListsItsSubagentsOnlyWhileTheSettingIsOn() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        let parent = Conversation.fixture(provider: .codex, projectPath: "/work/app", title: "Parent", updatedAt: .now)
        let subagent = Conversation.fixture(
            provider: .codex, projectPath: "/work/app", title: "Subagent", updatedAt: .now - 10, parentSessionID: parent.sessionID
        )
        store.replaceConversations(on: .thisMac, with: [parent, subagent])
        let project = try #require(store.sidebarProjectGroups.first { $0.projectPath == "/work/app" })
        var expanded = SidebarSubagentRows()
        expanded.toggle(parent.id)

        let hiddenHeight = fittingHeight(of: section(project, store: store, showsSubagents: false, subagentRows: expanded))
        let collapsedHeight = fittingHeight(of: section(project, store: store, showsSubagents: true, subagentRows: SidebarSubagentRows()))
        let shownHeight = fittingHeight(of: section(project, store: store, showsSubagents: true, subagentRows: expanded))

        #expect(hiddenHeight == collapsedHeight)
        #expect(shownHeight > hiddenHeight + 20, "The subagent's row adds about a row's height: \(hiddenHeight) → \(shownHeight)")
    }

    private func section(
        _ project: ProjectConversationGroup, store: ConversationStore, showsSubagents: Bool, subagentRows: SidebarSubagentRows
    ) -> some View {
        VStack(spacing: 0) {
            SidebarProjectSection(
                store: store,
                project: project,
                parentLabel: nil,
                pinDragging: SidebarPinDragging(drag: nil, rowFrames: SidebarRowFrames(), onDrag: { _, _, _, _ in }, onDrop: {}, onCancel: {}),
                hostProjectRows: { [] },
                isExpanded: true,
                isOnboardingTourProject: false,
                projectSelection: ProjectMultiSelection(),
                sessionSelection: SessionMultiSelection(),
                selectedConversations: [],
                showsSubagents: showsSubagents,
                subagentRows: subagentRows,
                onToggleSubagents: { _ in },
                messageMatches: [:],
                onToggleExpansion: {},
                onClickProject: {},
                onNewSession: { _ in },
                onClickConversation: { _ in },
                onSelectPendingNewSession: { _ in },
                onRenameConversation: { _ in },
                onRenameProject: {},
                onRemoveSelectedProjects: {},
                onRemoveSelectedProjectsAndDeleteSessions: {},
                onRequestDeletion: { _ in },
                onCloseTab: { _ in }
            )
        }
        .frame(width: 280)
    }

    private func fittingHeight(of view: some View) -> CGFloat {
        _ = NSApplication.shared
        let hostingView = NSHostingView(rootView: view)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize.height
    }
}
