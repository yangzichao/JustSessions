import AppKit
import SwiftUI

/// Drags tabs between windows, as Chrome does. A tab, or a split's two tabs, dragged off its window's tab bar leaves
/// the window, and a new window of the same size carries it, the tab staying under the pointer. The tab hides from the
/// bar at once, and the new window shows, with no opening animation, once it has laid the tab out under the pointer.
/// Over another window's tab bar, that window takes it, and it follows the pointer there among its group's tabs, or as
/// a group of its own among the groups; dragged off again, the window carrying it comes back. Let go, it stays where it
/// is, selected, its window in front. A window's only tabs carry their window from the start, and the window closes
/// once another window takes them. Their terminals and CLIs carry on throughout; see
/// `ConversationStore+TabsBetweenWindows`.
///
/// A group dragged by its label goes the same way with all its tabs, as Chrome drags a tab group: off the bar into a
/// window of its own, or into another window's bar as a group of its own, or among that window's tabs of its project.
///
/// A tab dragged over a window's terminals, its own window's or another's, shows there once let go, as a session
/// dragged into Claude Code's window does: in a split view on the side it was let go on, or on its own in the middle.
/// The window highlights where the tab would show, see `TerminalSplitDropTargets`, while the window carrying the tab,
/// if any, hides. Dragged down from its own tab bar, a tab that can show there stays in its window while over the
/// terminals, and a window carries it only once it leaves them; any other tab, such as the selected one, leaves the
/// window as soon as it leaves the bar.
///
/// The tab bar a drag starts in follows it until the pointer leaves the bar; see `TerminalTabGroupSection`. From then
/// on the drag follows the pointer here, since the view the drag started on goes away with the tab. Back over its bar
/// from its window's terminals, the bar follows the drag again.
///
/// The tab bar holding the tabs draws them through its window's `TabBarDragDisplays`, so a move of the pointer re-runs
/// only that bar's shifts of the tabs or groups, and no other window's bar.
@MainActor
final class TabDragBetweenWindows {
    static let shared = TabDragBetweenWindows()

    /// The dragged tabs as the tab bar holding them draws them, following the pointer.
    @MainActor
    private enum ShownDrag {
        /// Among their group's tabs and splits.
        case amongGroupTabs(groupKey: String, display: TabBarDragDisplay<[UUID]>, drag: TabBarDrag<[UUID]>)
        /// As their own group, among the groups.
        case amongGroups(display: TabBarDragDisplay<String>, drag: TabBarDrag<String>)

        var displayID: ObjectIdentifier {
            switch self {
            case .amongGroupTabs(_, let display, _): ObjectIdentifier(display)
            case .amongGroups(let display, _): ObjectIdentifier(display)
            }
        }

        func draw() {
            switch self {
            case .amongGroupTabs(_, let display, let drag): display.show(drag)
            case .amongGroups(let display, let drag): display.show(drag)
            }
        }

        func erase() {
            switch self {
            case .amongGroupTabs(_, let display, _): display.show(nil)
            case .amongGroups(let display, _): display.show(nil)
            }
        }
    }

    /// Drawn in its display, and taken out of the one it was drawn in before, if another.
    private var shownDrag: ShownDrag? {
        didSet {
            if let oldValue, oldValue.displayID != shownDrag?.displayID { oldValue.erase() }
            shownDrag?.draw()
        }
    }

    private struct WindowDragDisplays {
        weak var store: ConversationStore?
        let displays: TabBarDragDisplays
    }

    private var dragDisplaysByStore: [ObjectIdentifier: WindowDragDisplays] = [:]
    let layouts = TabBarLayouts()
    let splitDropTargets = TerminalSplitDropTargets()

    private struct Workspace {
        let store: ConversationStore
        let window: NSWindow
    }

    private enum Stage {
        /// In the tab bar the drag started in, which follows it.
        case inStartingBar
        /// Off the tab bar it started in, while a window opens to carry the tabs.
        case waitingForCarrier
        /// In the carrier window, which follows the pointer.
        case carried
        /// In this window's tab bar.
        case inTabBar(ConversationStore)
        /// Over this window's terminals, which show the tabs at this place once let go. The tabs are still in the
        /// window they started in, until a window carries them, and then in the carrier, hidden.
        case overTerminals(ConversationStore, TerminalDropPlace)
    }

    private struct Drag {
        let registry: WorkspaceWindowRegistry
        let startingStore: ConversationStore
        /// Where the drag started in its window, which tells it from a later drag.
        let startLocation: CGPoint
        /// The tab, a split's two tabs, or a whole group's tabs, in tab bar order.
        let tabIDs: [UUID]
        /// Dragged by its group's label: every tab of the group, which never drop onto the terminals.
        let isWholeGroup: Bool
        /// The tab the pointer took hold of, or for a whole group the tab that showed, which shows once dropped.
        let grabbedTabID: UUID
        /// The grabbed tab's title, which the terminals name where it would show.
        let grabbedTabTitle: String
        let grab: TabDragGrab
        /// The size of a window opened to carry the tabs: the size of the one they left.
        let windowSize: CGSize
        /// Where the tabs start in a window opened to carry them, until it lays them out: where their group's first tab
        /// started in the bar they left, past the groups before it.
        let estimatedCarrierTabsLeadingEdge: CGFloat
        /// Where the pointer was at the drag's latest mouse event, in screen coordinates.
        var pointer: CGPoint
        var stage = Stage.inStartingBar
        /// The window carrying the tabs while no tab bar holds them: one opened for them, or for a window's only tabs,
        /// their own. Hidden while a tab bar holds them.
        var carrier: Workspace?
        /// Let go while a window was opening to carry the tabs.
        var isReleased = false
    }

    private var drag: Drag?
    private var eventMonitor: Any?
    private var isLayoutFollowUpScheduled = false

    private init() {
        layouts.onChange = { [weak self] store in self?.followLayoutChange(in: store) }
    }

    // MARK: - Tab bars

    /// Where `store`'s tab bar draws tabs dragged in from another window while it holds them. A display's dragged
    /// item among a group's tabs is all the dragged tabs, together, which may be a whole group's.
    func dragDisplays(in store: ConversationStore) -> TabBarDragDisplays {
        let storeID = ObjectIdentifier(store)
        if let windowDisplays = dragDisplaysByStore[storeID], windowDisplays.store === store { return windowDisplays.displays }
        // A closed window's displays go once another window asks for its own.
        dragDisplaysByStore = dragDisplaysByStore.filter { $0.value.store != nil }
        let displays = TabBarDragDisplays()
        dragDisplaysByStore[storeID] = WindowDragDisplays(store: store, displays: displays)
        return displays
    }

    /// Follows tabs dragged in their window's tab bar, from `startLocation` in the window. Returns false once the drag
    /// goes on here instead: off the bar, or from the start for a window's only tabs.
    func followDragInTabBar(
        of tabIDs: [UUID],
        grabbing grabbedTabID: UUID,
        inGroup groupKey: String,
        of store: ConversationStore,
        from startLocation: CGPoint
    ) -> Bool {
        followDragInTabBar(
            of: tabIDs, grabbing: grabbedTabID, inGroup: groupKey, isWholeGroup: false, of: store, from: startLocation
        )
    }

    /// Follows a group dragged by its label in its window's tab bar, from `startLocation` in the window, as
    /// `followDragInTabBar(of:grabbing:inGroup:of:from:)` follows tabs. Its tabs go together; the one showing, or else
    /// its first, shows wherever they land.
    func followGroupDragInTabBar(_ groupKey: String, of store: ConversationStore, from startLocation: CGPoint) -> Bool {
        let groupTabIDs = store.terminalSessions.filter { store.tabGroupKey(of: $0) == groupKey }.map(\.id)
        guard let firstTabID = groupTabIDs.first else { return true }
        let shownTabID = groupTabIDs.first { $0 == store.selectedTerminalID } ?? firstTabID
        return followDragInTabBar(
            of: groupTabIDs, grabbing: shownTabID, inGroup: groupKey, isWholeGroup: true, of: store, from: startLocation
        )
    }

    private func followDragInTabBar(
        of tabIDs: [UUID],
        grabbing grabbedTabID: UUID,
        inGroup groupKey: String,
        isWholeGroup: Bool,
        of store: ConversationStore,
        from startLocation: CGPoint
    ) -> Bool {
        let pointer = NSEvent.currentPointerLocation
        if let drag {
            guard drag.startingStore !== store || drag.startLocation != startLocation || drag.tabIDs != tabIDs else {
                guard case .inStartingBar = drag.stage else { return false }
                self.drag?.pointer = pointer
                return followDragInStartingBar()
            }
            // Another drag started, so this one's end went unseen: the tabs stay where they are.
            switch drag.stage {
            case .inStartingBar: endDrag()
            case .overTerminals: leaveTabsOffTerminals()
            default: dropTabs()
            }
        }
        let layout = layouts.layout(of: store)
        guard let window = store.windowRegistry.window(of: store), let groupSpan = layout.groupSpans[groupKey] else { return true }
        let firstTabsOfGroup = store.tabStrip.movingUnits(inGroup: groupKey).first ?? tabIDs
        // A collapsed group shows only its label; its tabs would start right past it.
        let groupTabsLeadingEdge =
            firstTabsOfGroup.compactMap { layout.tabSpansInGroups[$0]?.minX }.min()
            ?? (isWholeGroup ? groupSpan.width : 0)
        // A whole group is grabbed by its label, before its tabs.
        let tabsLeadingEdge =
            isWholeGroup
            ? groupSpan.minX + groupTabsLeadingEdge
            : layout.span(ofTabs: tabIDs, inGroup: groupKey)?.minX
        guard let tabsLeadingEdge else { return true }
        let isWindowsOnlyTabs = store.terminalSessions.count == tabIDs.count
        // A window in full screen has nowhere to move.
        if isWindowsOnlyTabs && window.styleMask.contains(.fullScreen) { return true }
        drag = Drag(
            registry: store.windowRegistry,
            startingStore: store,
            startLocation: startLocation,
            tabIDs: tabIDs,
            isWholeGroup: isWholeGroup,
            grabbedTabID: grabbedTabID,
            grabbedTabTitle: store.terminalSessions.first { $0.id == grabbedTabID }?.displayTitle ?? "",
            grab: TabDragGrab(distanceFromTabsLeadingEdge: startLocation.x - tabsLeadingEdge, depthBelowWindowTop: startLocation.y),
            windowSize: window.frame.size,
            estimatedCarrierTabsLeadingEdge: (layout.groupsLeadingEdge ?? 0) + groupTabsLeadingEdge,
            pointer: pointer
        )
        guard isWindowsOnlyTabs else { return followDragInStartingBar() }
        drag?.carrier = Workspace(store: store, window: window)
        drag?.stage = .carried
        startFollowingPointer()
        return false
    }

    /// The tab bar the drag started in let go of it while the pointer was over the bar.
    func endDragInTabBar() {
        guard let drag, case .inStartingBar = drag.stage else { return }
        endDrag()
    }

    // MARK: - Following the pointer

    /// Whether the tab bar the drag started in still holds the tabs. Once the pointer leaves the bar, the window's
    /// terminals take a tab that can show there, or else a window opens to carry the tabs.
    private func followDragInStartingBar() -> Bool {
        guard let drag, let window = drag.registry.window(of: drag.startingStore),
            !TabBarBand(windowFrame: window.frame).holdsTab(at: drag.pointer)
        else { return true }
        let startingWorkspace = Workspace(store: drag.startingStore, window: window)
        if let place = terminalDropPlace(in: startingWorkspace, at: drag.pointer) {
            showTerminalDrop(at: place, in: startingWorkspace)
            startFollowingPointer()
            return false
        }
        return !openCarrier()
    }

    /// Opens a window to carry the tabs out of the window they started in, which takes them once open. Returns whether
    /// it is opening; if not, the tab bar they started in holds them again.
    private func openCarrier() -> Bool {
        guard let drag else { return false }
        self.drag?.stage = .waitingForCarrier
        let isOpening = drag.registry.openWindow { [weak self] store, window in
            self?.carrierOpened(Workspace(store: store, window: window))
        }
        guard isOpening else {
            self.drag?.stage = .inStartingBar
            return false
        }
        // Hidden where they were drawn, rather than sliding back into their places just before they go.
        dragDisplays(in: drag.startingStore).leavingTabIDs = Set(drag.tabIDs)
        startFollowingPointer()
        return true
    }

    private func carrierOpened(_ carrier: Workspace) {
        guard var drag, case .waitingForCarrier = drag.stage,
            let tabs = drag.startingStore.takeOutTabsForAnotherWindow(drag.tabIDs)
        else {
            // The drag ended without it.
            carrier.window.close()
            return
        }
        dragDisplays(in: drag.startingStore).leavingTabIDs = []
        carrier.window.setFrame(CGRect(origin: carrier.window.frame.origin, size: drag.windowSize), display: false)
        carrier.store.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(0), selecting: drag.grabbedTabID)
        drag.carrier = carrier
        drag.stage = .carried
        self.drag = drag
        followPointer()
        if drag.isReleased { dropTabs() }
    }

    private func followPointer() {
        guard let drag else { return }
        let pointer = drag.pointer
        switch drag.stage {
        case .inStartingBar, .waitingForCarrier:
            return
        case .carried:
            followCarriedTabs(to: pointer)
        case .inTabBar(let store):
            guard let window = drag.registry.window(of: store),
                TabBarBand(windowFrame: window.frame).holdsTab(at: pointer)
            else {
                moveTabsOutOfTabBar(of: store, to: pointer)
                return
            }
            showDrag(in: Workspace(store: store, window: window), at: pointer)
        case .overTerminals(let store, _):
            followTabsOverTerminals(of: store, to: pointer)
        }
    }

    /// Over another window's tab bar, the tabs join it; over a window's terminals that can show them, the carrier hides
    /// while that window highlights where they would show; anywhere else, the carrier follows the pointer, in sight
    /// once its tab bar has laid the tabs out under the pointer. A window opened to carry them shows only then.
    private func followCarriedTabs(to pointer: CGPoint) {
        guard let drag else { return }
        let workspace = workspace(at: pointer, besides: drag.carrier?.window)
        if let workspace, TabBarBand(windowFrame: workspace.window.frame).takesTab(at: pointer) {
            splitDropTargets.show(nil)
            moveTabs(intoTabBarOf: workspace, at: pointer)
        } else if let workspace, let place = terminalDropPlace(in: workspace, at: pointer) {
            showTerminalDrop(at: place, in: workspace)
        } else {
            splitDropTargets.show(nil)
            self.drag?.stage = .carried
            moveCarrier(to: pointer)
            if let carrier = drag.carrier, tabsSpan(in: carrier.store) != nil { showCarrier(carrier) }
        }
    }

    private func showCarrier(_ carrier: Workspace) {
        guard carrier.window.alphaValue == 0 else { return }
        carrier.window.alphaValue = 1
        carrier.window.orderFront(nil)
    }

    /// Tabs still in the window they started in stay there while over its terminals, go back to its tab bar's drag over
    /// the bar, and leave in a window opened to carry them anywhere else. Tabs in a carrier follow the pointer as
    /// carried tabs do.
    private func followTabsOverTerminals(of store: ConversationStore, to pointer: CGPoint) {
        guard let drag else { return }
        guard drag.carrier == nil else {
            followCarriedTabs(to: pointer)
            return
        }
        guard let window = drag.registry.window(of: store) else {
            leaveTabsOffTerminals()
            return
        }
        let workspace = Workspace(store: store, window: window)
        if TabBarBand(windowFrame: window.frame).holdsTab(at: pointer) {
            splitDropTargets.show(nil)
            // The bar's drag picks the tabs up again at the pointer's next move.
            self.drag?.stage = .inStartingBar
        } else if let place = terminalDropPlace(in: workspace, at: pointer) {
            showTerminalDrop(at: place, in: workspace)
        } else {
            splitDropTargets.show(nil)
            _ = openCarrier()
        }
    }

    /// Once the tabs' window lays them out anew, as when they arrive, they are placed under the pointer again.
    private func followLayoutChange(in store: ConversationStore) {
        guard let drag, !isLayoutFollowUpScheduled else { return }
        switch drag.stage {
        case .carried where drag.carrier?.store === store: break
        case .inTabBar(let holdingStore) where holdingStore === store: break
        default: return
        }
        isLayoutFollowUpScheduled = true
        // After the views' update that measured the change.
        DispatchQueue.main.async { [weak self] in
            self?.isLayoutFollowUpScheduled = false
            self?.followPointer()
        }
    }

    private func pointerReleased() {
        guard let drag else { return }
        switch drag.stage {
        case .inStartingBar:
            return
        case .waitingForCarrier:
            self.drag?.isReleased = true
            // A window that never opens leaves the tabs where they were.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, let drag = self.drag, drag.isReleased, case .waitingForCarrier = drag.stage else { return }
                drag.registry.cancelWindowHandOvers()
                self.endDrag()
            }
        case .carried, .inTabBar, .overTerminals:
            dropTabs()
        }
    }

    private func startFollowingPointer() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.drag?.pointer = event.screenLocation
                if event.type == .leftMouseUp {
                    self?.pointerReleased()
                } else {
                    self?.followPointer()
                }
            }
            return event
        }
    }

    private func endDrag() {
        if let drag {
            let startingDisplays = dragDisplays(in: drag.startingStore)
            if !startingDisplays.leavingTabIDs.isEmpty { startingDisplays.leavingTabIDs = [] }
        }
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        drag = nil
        shownDrag = nil
        splitDropTargets.show(nil)
    }

    // MARK: - Moving the tabs

    /// The workspace window on top under the pointer, past the carrier.
    private func workspace(at pointer: CGPoint, besides carrierWindow: NSWindow?) -> Workspace? {
        guard let drag else { return nil }
        var windowNumberAbove = 0
        // The carrier is under the pointer itself, and the windows are looked through from the top.
        for _ in 0..<4 {
            let windowNumber = NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: windowNumberAbove)
            guard windowNumber > 0 else { return nil }
            if windowNumber == carrierWindow?.windowNumber {
                windowNumberAbove = windowNumber
                continue
            }
            guard let (store, window) = drag.registry.workspace(withWindowNumber: windowNumber) else { return nil }
            return Workspace(store: store, window: window)
        }
        return nil
    }

    private func moveTabs(intoTabBarOf target: Workspace, at pointer: CGPoint) {
        guard var drag, let carrier = drag.carrier else { return }
        // Measured in the carrier, where the tabs are a group of their own, before they leave it.
        let carriedTabsDistanceFromGroupLeadingEdge = tabsDistanceFromGroupLeadingEdge(in: carrier.store) ?? 0
        guard let tabs = carrier.store.takeOutTabsForAnotherWindow(drag.tabIDs) else { return }
        let placement = layouts.layout(of: target.store).placement(
            forTabsOfGroup: tabs.unit.groupKey,
            leadingEdgeAt: target.window.convertPoint(fromScreen: pointer).x - drag.grab.distanceFromTabsLeadingEdge,
            tabsDistanceFromGroupLeadingEdge: carriedTabsDistanceFromGroupLeadingEdge,
            in: target.store.tabStrip
        )
        target.store.bringInTabsFromAnotherWindow(tabs, at: placement, selecting: drag.grabbedTabID)
        carrier.window.alphaValue = 0
        target.window.orderFront(nil)
        drag.stage = .inTabBar(target.store)
        self.drag = drag
        showDrag(in: target, at: pointer)
    }

    private func moveTabsOutOfTabBar(of store: ConversationStore, to pointer: CGPoint) {
        guard var drag, let carrier = drag.carrier, let tabs = store.takeOutTabsForAnotherWindow(drag.tabIDs) else { return }
        shownDrag = nil
        carrier.store.bringInTabsFromAnotherWindow(tabs, at: .asNewGroup(0), selecting: drag.grabbedTabID)
        drag.stage = .carried
        self.drag = drag
        // Below the bar, the window's terminals may take them, with the carrier still hidden.
        followCarriedTabs(to: pointer)
    }

    // MARK: - Dropping onto the terminals

    /// Where on the workspace's terminals the dragged tabs would show, let go at `pointer`.
    private func terminalDropPlace(in workspace: Workspace, at pointer: CGPoint) -> TerminalDropPlace? {
        guard let drag, !drag.isWholeGroup, workspace.store.canShowDroppedTabs(drag.tabIDs) else { return nil }
        return splitDropTargets.place(at: pointer, in: workspace.store, windowFrame: workspace.window.frame)
    }

    /// Highlights where on the workspace's terminals the tabs would show, hiding the window carrying them, if any.
    private func showTerminalDrop(at place: TerminalDropPlace, in workspace: Workspace) {
        guard let drag else { return }
        let isNewTarget: Bool
        if case .overTerminals(let store, _) = drag.stage { isNewTarget = store !== workspace.store } else { isNewTarget = true }
        self.drag?.stage = .overTerminals(workspace.store, place)
        drag.carrier?.window.alphaValue = 0
        if isNewTarget { workspace.window.orderFront(nil) }
        splitDropTargets.show(
            TerminalSplitDropTargets.Target(
                storeID: ObjectIdentifier(workspace.store),
                place: place,
                title: drag.grabbedTabTitle
            ))
    }

    /// Shows the dragged tab at `place` on the store's window's terminals, selected, the window in front. A tab in a
    /// carrier comes into the window first, at the end of its group, and the carrier closes once empty. Should the
    /// window no longer take it, as when its selected tab closed meanwhile, the tab stays where it was.
    private func dropTabsOnTerminals(at place: TerminalDropPlace, in store: ConversationStore) {
        guard let drag else { return }
        guard store.canShowDroppedTabs(drag.tabIDs) else {
            leaveTabsOffTerminals()
            return
        }
        if let carrier = drag.carrier, carrier.store !== store {
            guard let pivotTabID = store.selectedTerminalID,
                let tabs = carrier.store.takeOutTabsForAnotherWindow(drag.tabIDs)
            else {
                leaveTabsOffTerminals()
                return
            }
            let strip = store.tabStrip
            let groupKey = tabs.unit.groupKey
            let placement: TabStripPlacement =
                strip.groupKeysInOrder.contains(groupKey)
                ? .amongGroupTabs(strip.movingUnits(inGroup: groupKey).count)
                : .asNewGroup(strip.groupKeysInOrder.count)
            store.bringInTabsFromAnotherWindow(tabs, at: placement, selecting: pivotTabID)
            if carrier.store.terminalSessions.isEmpty { carrier.window.close() }
        }
        store.showDroppedTab(drag.grabbedTabID, at: place)
        drag.registry.window(of: store)?.makeKeyAndOrderFront(nil)
        endDrag()
    }

    /// Ends the drag with the tabs where they are, off the terminals they were over: in the window they started in, or
    /// in their carrier, which comes back in sight.
    private func leaveTabsOffTerminals() {
        if let drag, let carrier = drag.carrier {
            moveCarrier(to: drag.pointer)
            carrier.window.alphaValue = 1
            carrier.window.makeKeyAndOrderFront(nil)
        }
        endDrag()
    }

    /// Keeps the tabs under the pointer as when grabbed.
    private func moveCarrier(to pointer: CGPoint) {
        guard let drag, let carrier = drag.carrier else { return }
        let tabsLeadingEdge = tabsSpan(in: carrier.store)?.minX ?? drag.estimatedCarrierTabsLeadingEdge
        carrier.window.setFrameOrigin(
            drag.grab.carrierWindowOrigin(
                pointer: pointer,
                tabsLeadingEdge: tabsLeadingEdge,
                windowHeight: carrier.window.frame.height
            ))
    }

    /// Draws the tabs in the tab bar holding them under the pointer, once it has laid them out: among their group's
    /// tabs, together as one, or as their own group among the groups when they are the group's only ones.
    private func showDrag(in holder: Workspace, at pointer: CGPoint) {
        guard let drag, let tabsSpan = tabsSpan(in: holder.store),
            let groupKey = holder.store.terminalSessions.first(where: { $0.id == drag.grabbedTabID }).map(holder.store.tabGroupKey(of:))
        else { return }
        let layout = layouts.layout(of: holder.store)
        let strip = holder.store.tabStrip
        let displays = dragDisplays(in: holder.store)
        let translation = drag.grab.translation(
            pointerX: holder.window.convertPoint(fromScreen: pointer).x,
            tabsLeadingEdge: tabsSpan.minX
        )
        let units = strip.movingUnits(inGroup: groupKey, keepingTogether: drag.tabIDs)
        let nextShownDrag: ShownDrag?
        if units.count > 1 {
            let widths = units.compactMap { layout.span(ofTabs: $0, inGroup: groupKey)?.width }
            var tabDrag = units.first { Set($0) == Set(drag.tabIDs) }
                .flatMap { TabBarDrag(dragging: $0, among: units, widths: widths, spacing: 0) }
            tabDrag?.translation = translation
            nextShownDrag = tabDrag.map { .amongGroupTabs(groupKey: groupKey, display: displays.amongTabs(ofGroup: groupKey), drag: $0) }
        } else {
            let groupKeys = strip.groupKeysInOrder
            var groupDrag = TabBarDrag(
                dragging: groupKey,
                among: groupKeys,
                widths: groupKeys.compactMap { layout.groupSpans[$0]?.width },
                spacing: WorkspaceTabMetrics.groupSpacing
            )
            groupDrag?.translation = translation
            nextShownDrag = groupDrag.map { .amongGroups(display: displays.amongGroups, drag: $0) }
        }
        shownDrag = nextShownDrag
    }

    /// Where the dragged tabs lay out in the store's tab bar, once it has.
    private func tabsSpan(in store: ConversationStore) -> TabBarLayout.Span? {
        guard let drag, let grabbedTab = store.terminalSessions.first(where: { $0.id == drag.grabbedTabID }) else { return nil }
        return layouts.layout(of: store).span(ofTabs: drag.tabIDs, inGroup: store.tabGroupKey(of: grabbedTab))
    }

    /// How far the dragged tabs start past their group's leading edge in the store's tab bar, once it has laid them out.
    private func tabsDistanceFromGroupLeadingEdge(in store: ConversationStore) -> CGFloat? {
        guard let drag, let grabbedTab = store.terminalSessions.first(where: { $0.id == drag.grabbedTabID }),
            let tabsSpan = tabsSpan(in: store),
            let groupSpan = layouts.layout(of: store).groupSpans[store.tabGroupKey(of: grabbedTab)]
        else { return nil }
        return tabsSpan.minX - groupSpan.minX
    }

    /// Leaves the tabs where they are: in the tab bar holding them, at the place they were drawn, or in the carrier,
    /// which closes once empty; or, over a window's terminals, shows them there. Either way, their window comes to the
    /// front.
    private func dropTabs() {
        guard let drag else { return }
        switch drag.stage {
        case .overTerminals(let store, let place):
            dropTabsOnTerminals(at: place, in: store)
            return
        case .inStartingBar, .waitingForCarrier:
            break
        case .carried:
            if let carrier = drag.carrier {
                // Let go before its tab bar laid the tabs out, it shows where it is.
                showCarrier(carrier)
                carrier.window.makeKeyAndOrderFront(nil)
            }
        case .inTabBar(let store):
            if let window = drag.registry.window(of: store) {
                showDrag(in: Workspace(store: store, window: window), at: drag.pointer)
                placeShownTabs(in: store)
                window.makeKeyAndOrderFront(nil)
            }
            store.selectTerminal(drag.grabbedTabID)
            if let carrier = drag.carrier, carrier.store !== store, carrier.store.terminalSessions.isEmpty {
                carrier.window.close()
            }
        }
        endDrag()
    }

    /// Moves the tabs to the place the tab bar drew them at, unless its tabs changed meanwhile.
    private func placeShownTabs(in store: ConversationStore) {
        guard let drag else { return }
        let strip = store.tabStrip
        withAnimation(TabBarDragMetrics.slideAnimation) {
            switch shownDrag {
            case .amongGroupTabs(let groupKey, _, let tabDrag)
            where tabDrag.itemIDs == strip.movingUnits(inGroup: groupKey, keepingTogether: drag.tabIDs):
                store.moveTabs(drag.tabIDs, toPlaceInGroup: tabDrag.targetIndex)
            case .amongGroups(_, let groupDrag) where groupDrag.itemIDs == strip.groupKeysInOrder:
                store.moveTabGroup(groupDrag.draggedID, toPlace: groupDrag.targetIndex)
            default:
                break
            }
            shownDrag = nil
        }
    }
}
