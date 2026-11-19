import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
struct SidebarHoverMenusTests {
    @Test func theHostedSidebarAtRestHoldsNoRowsPopUpButtons() async throws {
        let harness = try await SidebarPerfHarness(sessionCount: 300)
        defer { harness.close() }

        let hostedViews = harness.hostedViews
        let popUpButtons = hostedViews.filter { $0 is NSPopUpButton }

        #expect(hostedViews.count > 50, "the browser is hosted (\(hostedViews.count) views)")
        #expect(
            popUpButtons.count <= 1, "\(popUpButtons.count) pop-up buttons at rest; a row's menus belong in the tree only under the pointer"
        )
    }

    @Test func eachRowAtRestHostsNoPopUpButton() async throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let conversation = Conversation.fixture(sessionID: "hover-menus")
        let window = try await host(
            VStack(spacing: 2) {
                projectRow(store: store, conversation: conversation, hovered: false)
                sessionRow(store: store, conversation: conversation, hovered: false)
                subagentRow(store: store, conversation: conversation, hovered: false)
                openTabsHeading(store: store, hovered: false)
            })
        defer { window.close() }

        var views: [NSView] = []
        func collect(_ view: NSView) {
            views.append(view)
            view.subviews.forEach(collect)
        }
        collect(window.contentView!)

        #expect(views.filter { $0 is NSPopUpButton }.isEmpty, "a row's menus are mounted at rest")
    }

    @Test func hoveringChangesNoRowsSize() throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let conversation = Conversation.fixture(sessionID: "hover-menus")

        func check(_ name: String, _ view: (Bool?) -> some View) {
            let atRest = NSHostingView(rootView: AnyView(view(false))).fittingSize
            let hovered = NSHostingView(rootView: AnyView(view(true))).fittingSize
            #expect(atRest == hovered, "\(name): \(atRest) at rest vs \(hovered) hovered")
        }
        check("project row") { projectRow(store: store, conversation: conversation, hovered: $0) }
        check("session row") { sessionRow(store: store, conversation: conversation, hovered: $0) }
        check("subagent row") { subagentRow(store: store, conversation: conversation, hovered: $0) }
        check("open tabs heading") { openTabsHeading(store: store, hovered: $0) }
    }

    @Test func thePlaceholderTakesTheMenusRoom() throws {
        _ = NSApplication.shared
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)
        let menus = NSHostingView(
            rootView: ProjectHoverActions(
                store: store,
                location: ProjectLocation(host: .thisMac, path: "/tmp/app"),
                projectDisplayName: "app",
                onNewSession: { _ in }
            ) { EmptyView() })
        let placeholder = NSHostingView(rootView: ProjectHoverActions<EmptyView>.placeholder)

        #expect(
            abs(placeholder.fittingSize.width - menus.fittingSize.width) <= 2,
            "placeholder \(placeholder.fittingSize) vs menus \(menus.fittingSize)")
        #expect(
            abs(placeholder.fittingSize.height - menus.fittingSize.height) <= 2,
            "placeholder \(placeholder.fittingSize) vs menus \(menus.fittingSize)")
    }

    private func projectRow(store: ConversationStore, conversation: Conversation, hovered: Bool?) -> some View {
        let project = ProjectConversationGroup.grouped([conversation]).first!
        return SidebarProjectRow(
            store: store,
            project: project,
            parentLabel: nil,
            isExpanded: false,
            projectSelection: ProjectMultiSelection(),
            onToggleExpansion: {},
            onClick: {},
            onNewSession: { _ in },
            onRename: {},
            onDeleteSessions: {},
            onRemoveProjectAndDeleteSessions: {},
            onRemoveSelectedProjects: {},
            onRemoveSelectedProjectsAndDeleteSessions: {},
            isHoveredForTests: hovered
        )
    }

    private func sessionRow(store: ConversationStore, conversation: Conversation, hovered: Bool?) -> some View {
        SidebarSessionRow(
            store: store,
            conversation: conversation,
            sessionSelection: SessionMultiSelection(),
            selectedConversations: [],
            subagentCount: 0,
            isShowingSubagents: false,
            onClick: { _ in },
            onToggleSubagents: {},
            onRename: { _ in },
            onRequestDeletion: { _ in },
            isHoveredForTests: hovered
        )
    }

    private func subagentRow(store: ConversationStore, conversation: Conversation, hovered: Bool?) -> some View {
        SidebarSubagentRow(
            store: store,
            row: SidebarSubagentRows.Row(conversation: conversation, depth: 1, subagentCount: 0),
            isSelected: false,
            isExpanded: false,
            onClick: { _ in },
            onToggleSubagents: {},
            isHoveredForTests: hovered
        )
    }

    private func openTabsHeading(store: ConversationStore, hovered: Bool?) -> some View {
        SidebarOpenTabGroupHeading(
            store: store,
            projectName: "app",
            location: ProjectLocation(host: .thisMac, path: "/tmp/app"),
            color: ThemePalette.ink,
            tabCount: 123,
            isCollapsed: false,
            hiddenTabsActivity: SessionActivitySummary(activities: []),
            onToggleCollapsed: {},
            onNewSession: { _ in },
            menuItems: TabGroupMenuItems(
                store: store,
                projectKey: "/tmp/app",
                projectDisplayName: "app",
                isCollapsed: false,
                onToggleCollapsed: {},
                allGroups: AllTabGroupsCollapsing(canCollapseAll: true, canExpandAll: false, collapseAll: {}, expandAll: {}),
                onCloseTabs: {}
            ),
            isHoveredForTests: hovered
        )
    }

    private func host(_ content: some View) async throws -> NSWindow {
        _ = NSApplication.shared
        let hostingView = NSHostingView(rootView: AnyView(content.padding(8)))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.orderFrontRegardless()
        for _ in 0..<4 {
            hostingView.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
        return window
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
}
