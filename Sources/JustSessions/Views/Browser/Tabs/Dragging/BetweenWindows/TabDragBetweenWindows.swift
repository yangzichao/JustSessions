import AppKit
import SwiftUI

/// Drags tabs between windows, as Chrome does. A tab, or a split's two tabs, dragged off its window's tab bar leaves
/// the window, and a new window of the same size carries it, the tab staying under the pointer. Over another window's
/// tab bar, that window takes it, and it follows the pointer there among its group's tabs, or as a group of its own
/// among the groups; dragged off again, the window carrying it comes back. Let go, it stays where it is, selected, its
/// window in front. A window's only tabs carry their window from the start, and the window closes once another window
/// takes them. Their terminals and CLIs carry on throughout; see `ConversationStore+TabsBetweenWindows`.
///
/// The tab bar a drag starts in follows it until the pointer leaves the bar; see `TerminalTabGroupSection`. From then
/// on the drag follows the pointer here, since the view the drag started on goes away with the tab.
@MainActor
final class TabDragBetweenWindows: ObservableObject {
    static let shared = TabDragBetweenWindows()

    /// The dragged tabs as the tab bar holding them draws them, following the pointer.
    enum ShownDrag: Equatable {
        /// Among their group's tabs and splits.
        case amongGroupTabs(storeID: ObjectIdentifier, groupKey: String, drag: TabBarDrag<[UUID]>)
        /// As their own group, among the groups.
        case amongGroups(storeID: ObjectIdentifier, drag: TabBarDrag<String>)
    }

    @Published private(set) var shownDrag: ShownDrag?
    let layouts = TabBarLayouts()

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
    }

    private struct Drag {
        let registry: WorkspaceWindowRegistry
        let startingStore: ConversationStore
        /// Where the drag started in its window, which tells it from a later drag.
        let startLocation: CGPoint
        /// The tab, or a split's two tabs, in tab bar order.
        let tabIDs: [UUID]
        /// The tab the pointer took hold of, which shows once dropped.
        let grabbedTabID: UUID
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

    /// The drag of the tabs among `groupKey`'s tabs, while `store`'s tab bar holds them there.
    func tabDrag(in store: ConversationStore, groupKey: String) -> TabBarDrag<[UUID]>? {
        guard case .amongGroupTabs(let storeID, let shownGroupKey, let tabDrag) = shownDrag,
              storeID == ObjectIdentifier(store), shownGroupKey == groupKey else { return nil }
        return tabDrag
    }

    /// The drag of the tabs' group among the groups, while `store`'s tab bar holds them as a group of their own.
    func groupDrag(in store: ConversationStore) -> TabBarDrag<String>? {
        guard case .amongGroups(let storeID, let groupDrag) = shownDrag, storeID == ObjectIdentifier(store) else { return nil }
        return groupDrag
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
        let pointer = NSEvent.currentPointerLocation
        if let drag {
            guard drag.startingStore !== store || drag.startLocation != startLocation || drag.tabIDs != tabIDs else {
                guard case .inStartingBar = drag.stage else { return false }
                self.drag?.pointer = pointer
                return followDragInStartingBar()
            }
            // Another drag started, so this one's end went unseen.
            if case .inStartingBar = drag.stage {
                self.drag = nil
            } else {
                dropTabs()
            }
        }
        let layout = layouts.layout(of: store)
        guard let window = store.windowRegistry.window(of: store),
              let tabsSpan = layout.span(ofTabs: tabIDs, inGroup: groupKey) else { return true }
        let isWindowsOnlyTabs = store.terminalSessions.count == tabIDs.count
        // A window in full screen has nowhere to move.
        if isWindowsOnlyTabs && window.styleMask.contains(.fullScreen) { return true }
        let firstTabsOfGroup = store.tabStrip.movingUnits(inGroup: groupKey).first ?? tabIDs
        let groupTabsLeadingEdge = firstTabsOfGroup.compactMap { layout.tabSpansInGroups[$0]?.minX }.min() ?? 0
        drag = Drag(
            registry: store.windowRegistry,
            startingStore: store,
            startLocation: startLocation,
            tabIDs: tabIDs,
            grabbedTabID: grabbedTabID,
            grab: TabDragGrab(distanceFromTabsLeadingEdge: startLocation.x - tabsSpan.minX, depthBelowWindowTop: startLocation.y),
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

    /// The tab bar the drag started in let go of it before the pointer left the bar.
    func endDragInTabBar() {
        guard let drag, case .inStartingBar = drag.stage else { return }
        self.drag = nil
    }

    // MARK: - Following the pointer

    /// Whether the tab bar the drag started in still holds the tabs. Once the pointer leaves the bar, a window opens to
    /// carry them.
    private func followDragInStartingBar() -> Bool {
        guard let drag, let window = drag.registry.window(of: drag.startingStore),
              !TabBarBand(windowFrame: window.frame).holdsTab(at: drag.pointer) else { return true }
        self.drag?.stage = .waitingForCarrier
        let isOpening = drag.registry.openWindow { [weak self] store, window in
            self?.carrierOpened(Workspace(store: store, window: window))
        }
        guard isOpening else {
            self.drag?.stage = .inStartingBar
            return true
        }
        startFollowingPointer()
        return false
    }

    private func carrierOpened(_ carrier: Workspace) {
        guard var drag, case .waitingForCarrier = drag.stage,
              let tabs = drag.startingStore.takeOutTabsForAnotherWindow(drag.tabIDs) else {
            // The drag ended without it.
            carrier.window.close()
            return
        }
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
            if let target = workspaceTakingTabs(at: pointer, besides: drag.carrier?.window) {
                moveTabs(intoTabBarOf: target, at: pointer)
            } else {
                moveCarrier(to: pointer)
            }
        case .inTabBar(let store):
            guard let window = drag.registry.window(of: store),
                  TabBarBand(windowFrame: window.frame).holdsTab(at: pointer) else {
                moveTabsOutOfTabBar(of: store, to: pointer)
                return
            }
            showDrag(in: Workspace(store: store, window: window), at: pointer)
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
        case .carried, .inTabBar:
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
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        drag = nil
        shownDrag = nil
    }

    // MARK: - Moving the tabs

    /// The workspace window on top under the pointer, past the carrier, while the pointer is over its tab bar.
    private func workspaceTakingTabs(at pointer: CGPoint, besides carrierWindow: NSWindow?) -> Workspace? {
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
            guard let (store, window) = drag.registry.workspace(withWindowNumber: windowNumber),
                  TabBarBand(windowFrame: window.frame).takesTab(at: pointer) else { return nil }
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
        moveCarrier(to: pointer)
        carrier.window.alphaValue = 1
        carrier.window.orderFront(nil)
    }

    /// Keeps the tabs under the pointer as when grabbed.
    private func moveCarrier(to pointer: CGPoint) {
        guard let drag, let carrier = drag.carrier else { return }
        let tabsLeadingEdge = tabsSpan(in: carrier.store)?.minX ?? drag.estimatedCarrierTabsLeadingEdge
        carrier.window.setFrameOrigin(drag.grab.carrierWindowOrigin(
            pointer: pointer,
            tabsLeadingEdge: tabsLeadingEdge,
            windowHeight: carrier.window.frame.height
        ))
    }

    /// Draws the tabs in the tab bar holding them under the pointer, once it has laid them out: among their group's
    /// tabs, or as their own group among the groups when they are the group's only ones.
    private func showDrag(in holder: Workspace, at pointer: CGPoint) {
        guard let drag, let tabsSpan = tabsSpan(in: holder.store),
              let groupKey = holder.store.terminalSessions.first(where: { $0.id == drag.grabbedTabID }).map(holder.store.tabGroupKey(of:)) else { return }
        let layout = layouts.layout(of: holder.store)
        let strip = holder.store.tabStrip
        let storeID = ObjectIdentifier(holder.store)
        let translation = drag.grab.translation(
            pointerX: holder.window.convertPoint(fromScreen: pointer).x,
            tabsLeadingEdge: tabsSpan.minX
        )
        let units = strip.movingUnits(inGroup: groupKey)
        let nextShownDrag: ShownDrag?
        if units.count > 1 {
            let widths = units.compactMap { layout.span(ofTabs: $0, inGroup: groupKey)?.width }
            var tabDrag = units.first { Set($0) == Set(drag.tabIDs) }
                .flatMap { TabBarDrag(dragging: $0, among: units, widths: widths, spacing: 0) }
            tabDrag?.translation = translation
            nextShownDrag = tabDrag.map { .amongGroupTabs(storeID: storeID, groupKey: groupKey, drag: $0) }
        } else {
            let groupKeys = strip.groupKeysInOrder
            var groupDrag = TabBarDrag(
                dragging: groupKey,
                among: groupKeys,
                widths: groupKeys.compactMap { layout.groupSpans[$0]?.width },
                spacing: WorkspaceTabMetrics.groupSpacing
            )
            groupDrag?.translation = translation
            nextShownDrag = groupDrag.map { .amongGroups(storeID: storeID, drag: $0) }
        }
        if shownDrag != nextShownDrag { shownDrag = nextShownDrag }
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
              let groupSpan = layouts.layout(of: store).groupSpans[store.tabGroupKey(of: grabbedTab)] else { return nil }
        return tabsSpan.minX - groupSpan.minX
    }

    /// Leaves the tabs where they are: in the tab bar holding them, at the place they were drawn, or in the carrier,
    /// which closes once empty. Either way, their window comes to the front.
    private func dropTabs() {
        guard let drag else { return }
        switch drag.stage {
        case .inStartingBar, .waitingForCarrier:
            break
        case .carried:
            drag.carrier?.window.makeKeyAndOrderFront(nil)
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
            case .amongGroupTabs(_, let groupKey, let tabDrag) where tabDrag.itemIDs == strip.movingUnits(inGroup: groupKey):
                store.moveTab(drag.grabbedTabID, toPlaceInGroup: tabDrag.targetIndex)
            case .amongGroups(_, let groupDrag) where groupDrag.itemIDs == strip.groupKeysInOrder:
                store.moveTabGroup(groupDrag.draggedID, toPlace: groupDrag.targetIndex)
            default:
                break
            }
            shownDrag = nil
        }
    }
}
