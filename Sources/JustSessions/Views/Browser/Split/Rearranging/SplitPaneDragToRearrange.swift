import AppKit
import SwiftUI

@MainActor
final class SplitPaneDragToRearrange {
    static let shared = SplitPaneDragToRearrange()
    static let distanceBeforePlacing: CGFloat = 24

    private struct Drag {
        let tabID: UUID
        let store: ConversationStore
        let place: TerminalDropPlace?
    }

    private var drag: Drag?
    private var splitDropTargets: TerminalSplitDropTargets { TabDragBetweenWindows.shared.splitDropTargets }

    private init() {}

    func follow(_ tabID: UUID, titled title: String, translation: CGSize, in store: ConversationStore) {
        guard store.shownSplit?.contains(tabID) == true else { return cancel() }
        let hasMovedFarEnough = hypot(translation.width, translation.height) >= Self.distanceBeforePlacing
        let place = hasMovedFarEnough ? placeOnTerminals(at: NSEvent.mouseLocation, in: store) : nil
        drag = Drag(tabID: tabID, store: store, place: place)
        splitDropTargets.show(place.map { TerminalSplitDropTargets.Target(storeID: ObjectIdentifier(store), place: $0, title: title) })
    }

    func drop() {
        defer { cancel() }
        guard let drag, let place = drag.place else { return }
        drag.store.rearrangeShownSplit(placing: drag.tabID, at: place)
    }

    func cancel(_ tabID: UUID) {
        if drag?.tabID == tabID { cancel() }
    }

    private func cancel() {
        drag = nil
        splitDropTargets.show(nil)
    }

    private func placeOnTerminals(at pointer: CGPoint, in store: ConversationStore) -> TerminalDropPlace? {
        guard let window = store.windowRegistry.window(of: store),
            NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: 0) == window.windowNumber
        else { return nil }
        return splitDropTargets.place(at: pointer, in: store, windowFrame: window.frame, ignoringShownSplit: true)
    }
}

extension View {
    func splitPaneDragToRearrange(_ tabID: UUID, titled title: String, in store: ConversationStore) -> some View {
        modifier(SplitPaneDragToRearrangeGesture(tabID: tabID, title: title, store: store))
    }
}

private struct SplitPaneDragToRearrangeGesture: ViewModifier {
    let tabID: UUID
    let title: String
    let store: ConversationStore

    /// SwiftUI resets it as the drag ends, whether let go or cancelled; a gesture's own `onEnded` misses a cancel.
    @GestureState private var isDragging = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .updating($isDragging) { _, isDragging, _ in isDragging = true }
                    .onChanged { value in
                        SplitPaneDragToRearrange.shared.follow(tabID, titled: title, translation: value.translation, in: store)
                    }
            )
            .onChange(of: isDragging) { _, isDragging in
                if !isDragging { SplitPaneDragToRearrange.shared.drop() }
            }
            .onDisappear { SplitPaneDragToRearrange.shared.cancel(tabID) }
    }
}
