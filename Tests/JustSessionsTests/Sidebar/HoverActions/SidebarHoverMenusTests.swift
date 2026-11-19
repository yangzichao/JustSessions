import AppKit
import SwiftUI
import Testing

@testable import JustSessions

/// The ⋯ and + menus a sidebar row shows under the pointer are in the view tree only while it is there. Each is an
/// AppKit pop-up button underneath, and one or two per row, kept at zero opacity, were re-laid out and re-registered
/// with accessibility on every change the sidebar observed: most of a tab switch's 270 ms; see item 20 in
/// docs/development/performance.md. While they are not there, the count they trade with stays in the layout, faded
/// out, beside a placeholder of the menus' size, so hovering shifts nothing.
@MainActor
struct SidebarHoverMenusTests {
    /// With 300 sessions in 50 projects, the hosted sidebar at rest holds only its header's filter pop-up: before, it
    /// held one per project row too, 49 of them among 283 AppKit views for the window.
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

    /// Each row type that trades its count for menus hosts no pop-up button at rest. The host heading keeps its menus
    /// mounted and faded, there being one heading per SSH host rather than one per row.
    @Test func eachRowAtRestHostsNoPopUpButton() async throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let conversation = Conversation.fixture(sessionID: "hover-menus")
        // Forced to rest, so where the pointer happens to be cannot mount a menu mid-test.
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

    /// Hovering mounts the menus in the count's place without moving anything: the row's size is the same with the
    /// pointer over it and without, for every row type that swaps.
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

    /// The placeholder a row lays out instead of its menus takes their room, give or take the point by which Macs draw
    /// them differently: 40 points wide on a developer's Mac and 41 on the release workflow's virtual machine, both
    /// macOS 26. The menus lie over the placeholder rather than beside it, so that point moves nothing;
    /// `hoveringChangesNoRowsSize` checks.
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

    // MARK: - Rows under test

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

    // MARK: - Hosting

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
