import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// The tab bar alone in a window out of sight, wide enough that every tab takes its full width, taking clicks and
/// drags sent as mouse events. Places in the bar are worked out from the tab bar's own sizes and each group label's
/// measured width, so a click lands where the bar draws the tab or label.
@MainActor
final class TabBarWindowFixture {
    let store: ConversationStore
    private(set) var closeRequests: [UUID] = []

    private let settings: IsolatedUserDefaults
    private var hostingView: NSHostingView<AnyView>?
    private let window: NSWindow
    private var eventTimestamp = ProcessInfo.processInfo.systemUptime
    private static let barSize = CGSize(width: 1_400, height: 40)

    init() throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        // Borderless, so it can sit far off screen; on screen, so SwiftUI takes the mouse events sent to it.
        window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -8_000, y: -8_000), size: Self.barSize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
    }

    /// Opens a plain terminal tab titled `title` in the project.
    @discardableResult
    func openTab(_ title: String, in projectPath: String) -> TerminalSession {
        let tab = TerminalSession(
            conversation: nil,
            provider: nil,
            projectPath: projectPath,
            action: nil,
            displayTitle: title,
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
        store.openTerminal(tab)
        return tab
    }

    func showTabBar() async throws {
        let hostingView = NSHostingView(rootView: AnyView(
            WorkspaceTabBar(
                store: store,
                leadingClearance: 0,
                onRenameConversation: { _ in },
                onCloseTerminal: { [weak self] in self?.closeRequests.append($0) }
            )
            .frame(width: Self.barSize.width, height: Self.barSize.height)
        ))
        self.hostingView = hostingView
        window.contentView = hostingView
        window.orderFrontRegardless()
        try await settle()
    }

    // MARK: - Mouse

    func click(atX x: CGFloat) async throws {
        try await send(.leftMouseDown, atX: x)
        try await send(.leftMouseUp, atX: x)
        try await settle()
    }

    /// Presses at `x`, moves the pointer `distance` along the bar in steps, and lets go. With `drop`, the pointer also
    /// moves that far down, out of the bar and the window.
    func drag(fromX x: CGFloat, by distance: CGFloat, droppingBy drop: CGFloat = 0) async throws {
        try await send(.leftMouseDown, atX: x)
        let stepCount = 10
        for step in 1...stepCount {
            let fraction = CGFloat(step) / CGFloat(stepCount)
            try await send(.leftMouseDragged, atX: x + distance * fraction, droppedBy: drop * fraction)
        }
        try await send(.leftMouseUp, atX: x + distance, droppedBy: drop)
        try await settle()
    }

    func press(atX x: CGFloat) async throws {
        try await send(.leftMouseDown, atX: x)
    }

    func release(atX x: CGFloat, droppedBy drop: CGFloat = 0) async throws {
        try await send(.leftMouseUp, atX: x, droppedBy: drop)
        try await settle()
    }

    // MARK: - Moving the window

    var isWindowMovable: Bool { window.isMovable }

    /// What a press at `x` would do, worked out without sending it, so it moves no window.
    func response(toPressAtX x: CGFloat) throws -> WindowMoveZoneMonitor.Response {
        WindowMoveZoneMonitor.shared.response(to: try event(.leftMouseDown, atX: x))
    }

    /// Moves the pointer into or out of the bar's window move zone, as its tracking area reports it.
    func movePointer(intoTheBar isIntoTheBar: Bool) throws {
        let zone = try #require(hostingView.flatMap { Self.zone(in: $0) })
        eventTimestamp += 0.02
        let event = try #require(NSEvent.enterExitEvent(
            with: isIntoTheBar ? .mouseEntered : .mouseExited, location: .zero, modifierFlags: [],
            timestamp: eventTimestamp, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            trackingNumber: 0, userData: nil
        ))
        if isIntoTheBar { zone.mouseEntered(with: event) } else { zone.mouseExited(with: event) }
    }

    // MARK: - Places in the bar

    /// The middle of the tab's select button, with the tab bar's tabs at their full width.
    func middle(ofTab tabID: UUID) throws -> CGFloat {
        let (leadingEdge, width) = try tabSpan(tabID)
        return leadingEdge + width / 2 - 10
    }

    func middle(ofCloseButtonOf tabID: UUID) throws -> CGFloat {
        let (leadingEdge, width) = try tabSpan(tabID)
        // The 16-point × ends 6 points before the tab's trailing edge.
        return leadingEdge + width - 6 - 8
    }

    func middle(ofGroupLabel groupKey: String) throws -> CGFloat {
        try groupLeadingEdge(groupKey) + (labelWidth(groupKey) - 6) / 2
    }

    /// Between the group's label and its first tab.
    func gap(afterGroupLabel groupKey: String) throws -> CGFloat {
        try groupLeadingEdge(groupKey) + labelWidth(groupKey) - 3
    }

    /// Between the group and the one before it.
    func gap(beforeGroup groupKey: String) throws -> CGFloat {
        try groupLeadingEdge(groupKey) - WorkspaceTabMetrics.groupSpacing / 2
    }

    /// Past every tab.
    var emptyEndOfTheBar: CGFloat { Self.barSize.width - 20 }

    func close() {
        hostingView?.rootView = AnyView(EmptyView())
        window.close()
        store.closeAllTerminals()
        settings.removeSuite()
    }

    // MARK: - Helpers

    /// Halfway down the tabs, in window coordinates.
    private static let pointerY = barSize.height / 2 - 2

    private func send(_ type: NSEvent.EventType, atX x: CGFloat, droppedBy drop: CGFloat = 0) async throws {
        NSApp.sendEvent(try event(type, atX: x, droppedBy: drop))
        try await Task.sleep(for: .milliseconds(20))
    }

    private func event(_ type: NSEvent.EventType, atX x: CGFloat, droppedBy drop: CGFloat = 0) throws -> NSEvent {
        eventTimestamp += 0.02
        return try #require(NSEvent.mouseEvent(
            with: type, location: CGPoint(x: x, y: Self.pointerY - drop), modifierFlags: [],
            timestamp: eventTimestamp, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1
        ))
    }

    private static func zone(in view: NSView) -> WindowMoveZoneView? {
        if let zone = view as? WindowMoveZoneView { return zone }
        return view.subviews.lazy.compactMap { zone(in: $0) }.first
    }

    private func settle() async throws {
        for _ in 0..<6 {
            hostingView?.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(30))
        }
    }

    private func tabWidth(_ tabID: UUID) -> CGFloat {
        let fullWidth = WorkspaceTabMetrics.maximumWidth
        return store.split(containing: tabID) == nil ? fullWidth : WorkspaceTabWidth.splitTabWidth(forTabWidth: fullWidth)
    }

    private func tabSpan(_ tabID: UUID) throws -> (leadingEdge: CGFloat, width: CGFloat) {
        let tab = try #require(store.terminalSessions.first { $0.id == tabID })
        let groupKey = store.tabGroupKey(of: tab)
        let groupTabs = store.terminalSessions.filter { store.tabGroupKey(of: $0) == groupKey }
        let tabsBefore = groupTabs.prefix { $0.id != tabID }
        let leadingEdge = try groupLeadingEdge(groupKey) + labelWidth(groupKey) + tabsBefore.map { tabWidth($0.id) }.reduce(0, +)
        return (leadingEdge, tabWidth(tabID))
    }

    private func groupLeadingEdge(_ groupKey: String) throws -> CGFloat {
        let groupKeys = store.tabStrip.groupKeysInOrder
        let groupIndex = try #require(groupKeys.firstIndex(of: groupKey))
        var leadingEdge = WorkspaceTabMetrics.horizontalInset
        for earlierGroupKey in groupKeys.prefix(groupIndex) {
            let tabsWidth = store.terminalSessions
                .filter { store.tabGroupKey(of: $0) == earlierGroupKey }
                .map { tabWidth($0.id) }
                .reduce(0, +)
            leadingEdge += labelWidth(earlierGroupKey) + tabsWidth + WorkspaceTabMetrics.groupSpacing
        }
        return leadingEdge
    }

    /// The expanded group's label, measured on its own, with the 6 points the group leaves after it.
    private func labelWidth(_ groupKey: String) -> CGFloat {
        let label = TerminalTabGroupLabel(
            projectName: store.projectDisplayName(forProjectPath: groupKey),
            location: ProjectLocation(key: groupKey),
            color: ThemePalette.ink,
            tabCount: 1,
            isCollapsed: false,
            hiddenTabCount: 0,
            hiddenTabsActivity: SessionActivitySummary(tabs: []),
            onToggleCollapsed: {}
        )
        return NSHostingView(rootView: label).fittingSize.width + 6
    }
}
