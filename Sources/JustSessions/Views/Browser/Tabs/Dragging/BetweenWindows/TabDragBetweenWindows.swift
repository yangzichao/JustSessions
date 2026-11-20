import AppKit
import SwiftUI

@MainActor
final class TabDragBetweenWindows {
    static let shared = TabDragBetweenWindows()
    private static let howLongALetGoDragWaitsForItsCarrierWindowToOpen = DispatchTimeInterval.seconds(2)

    @MainActor
    private enum ShownDrag {
        case amongGroupTabs(groupKey: String, display: TabBarDragDisplay<[UUID]>, drag: TabBarDrag<[UUID]>)
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
        case inStartingBar
        case waitingForCarrier
        case carried
        case inTabBar(ConversationStore)
        case overTerminals(ConversationStore, TerminalDropPlace)
    }

    private struct Drag {
        let registry: WorkspaceWindowRegistry
        let startingStore: ConversationStore
        let startLocation: CGPoint
        let tabIDs: [UUID]
        let isWholeGroup: Bool
        let grabbedTabID: UUID
        let grabbedTabTitle: String
        let grab: TabDragGrab
        let windowSize: CGSize
        let estimatedCarrierTabsLeadingEdge: CGFloat
        var pointer: CGPoint
        var stage = Stage.inStartingBar
        var carrier: Workspace?
        var isLetGoWhileWaitingForCarrier = false
    }

    private var drag: Drag?
    private var eventMonitor: Any?
    private var isPointerFollowUpAfterLayoutUpdateScheduled = false

    private init() {
        layouts.onChange = { [weak self] store in self?.followLayoutChange(in: store) }
    }

    func dragDisplays(in store: ConversationStore) -> TabBarDragDisplays {
        let storeID = ObjectIdentifier(store)
        if let windowDisplays = dragDisplaysByStore[storeID], windowDisplays.store === store { return windowDisplays.displays }
        dragDisplaysByStore = dragDisplaysByStore.filter { $0.value.store != nil }
        let displays = TabBarDragDisplays()
        dragDisplaysByStore[storeID] = WindowDragDisplays(store: store, displays: displays)
        return displays
    }

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
            switch drag.stage {
            case .inStartingBar: endDrag()
            case .overTerminals: leaveTabsOffTerminals()
            default: dropTabs()
            }
        }
        let layout = layouts.layout(of: store)
        guard let window = store.windowRegistry.window(of: store), let groupSpan = layout.groupSpans[groupKey] else { return true }
        let firstTabsOfGroup = store.tabStrip.movingUnits(inGroup: groupKey).first ?? tabIDs
        let groupTabsLeadingEdge =
            firstTabsOfGroup.compactMap { layout.tabSpansInGroups[$0]?.minX }.min()
            ?? (isWholeGroup ? groupSpan.width : 0)
        let tabsLeadingEdge =
            isWholeGroup
            ? groupSpan.minX + groupTabsLeadingEdge
            : layout.span(ofTabs: tabIDs, inGroup: groupKey)?.minX
        guard let tabsLeadingEdge else { return true }
        let isWindowsOnlyTabs = store.terminalSessions.count == tabIDs.count
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

    func endDragInTabBar() {
        guard let drag, case .inStartingBar = drag.stage else { return }
        endDrag()
    }

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
        dragDisplays(in: drag.startingStore).leavingTabIDs = Set(drag.tabIDs)
        startFollowingPointer()
        return true
    }

    private func carrierOpened(_ carrier: Workspace) {
        guard var drag, case .waitingForCarrier = drag.stage,
            let tabs = drag.startingStore.takeOutTabsForAnotherWindow(drag.tabIDs)
        else {
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
        if drag.isLetGoWhileWaitingForCarrier { dropTabs() }
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
            self.drag?.stage = .inStartingBar
        } else if let place = terminalDropPlace(in: workspace, at: pointer) {
            showTerminalDrop(at: place, in: workspace)
        } else {
            splitDropTargets.show(nil)
            _ = openCarrier()
        }
    }

    private func followLayoutChange(in store: ConversationStore) {
        guard let drag, !isPointerFollowUpAfterLayoutUpdateScheduled else { return }
        switch drag.stage {
        case .carried where drag.carrier?.store === store: break
        case .inTabBar(let holdingStore) where holdingStore === store: break
        default: return
        }
        followPointerAfterTheViewUpdateThatMeasuredTheNewLayout()
    }

    private func followPointerAfterTheViewUpdateThatMeasuredTheNewLayout() {
        isPointerFollowUpAfterLayoutUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.isPointerFollowUpAfterLayoutUpdateScheduled = false
            self?.followPointer()
        }
    }

    private func pointerReleased() {
        guard let drag else { return }
        switch drag.stage {
        case .inStartingBar:
            return
        case .waitingForCarrier:
            self.drag?.isLetGoWhileWaitingForCarrier = true
            leaveTabsWhereTheyWereIfTheCarrierWindowNeverOpens()
        case .carried, .inTabBar, .overTerminals:
            dropTabs()
        }
    }

    private func leaveTabsWhereTheyWereIfTheCarrierWindowNeverOpens() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.howLongALetGoDragWaitsForItsCarrierWindowToOpen) { [weak self] in
            guard let self, let drag = self.drag, drag.isLetGoWhileWaitingForCarrier, case .waitingForCarrier = drag.stage
            else { return }
            drag.registry.cancelWindowHandOvers()
            self.endDrag()
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

    private func workspace(at pointer: CGPoint, besides carrierWindow: NSWindow?) -> Workspace? {
        guard let drag else { return nil }
        var windowNumberAbove = 0
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
        followCarriedTabs(to: pointer)
    }

    private func terminalDropPlace(in workspace: Workspace, at pointer: CGPoint) -> TerminalDropPlace? {
        guard let drag, !drag.isWholeGroup, workspace.store.canShowDroppedTabs(drag.tabIDs) else { return nil }
        return splitDropTargets.place(at: pointer, in: workspace.store, windowFrame: workspace.window.frame)
    }

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

    private func leaveTabsOffTerminals() {
        if let drag, let carrier = drag.carrier {
            moveCarrier(to: drag.pointer)
            carrier.window.alphaValue = 1
            carrier.window.makeKeyAndOrderFront(nil)
        }
        endDrag()
    }

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

    private func tabsSpan(in store: ConversationStore) -> TabBarLayout.Span? {
        guard let drag, let grabbedTab = store.terminalSessions.first(where: { $0.id == drag.grabbedTabID }) else { return nil }
        return layouts.layout(of: store).span(ofTabs: drag.tabIDs, inGroup: store.tabGroupKey(of: grabbedTab))
    }

    private func tabsDistanceFromGroupLeadingEdge(in store: ConversationStore) -> CGFloat? {
        guard let drag, let grabbedTab = store.terminalSessions.first(where: { $0.id == drag.grabbedTabID }),
            let tabsSpan = tabsSpan(in: store),
            let groupSpan = layouts.layout(of: store).groupSpans[store.tabGroupKey(of: grabbedTab)]
        else { return nil }
        return tabsSpan.minX - groupSpan.minX
    }

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
