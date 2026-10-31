import AppKit
import SwiftUI

/// Follows a shown split's pane dragged by its mini toolbar, as a tab is dragged onto the terminals: the edge of the
/// terminals under the pointer lights up where the pane's tab would sit, on the left or right side by side, on top or
/// below stacked, or the middle, on its own with the split separated; let go, the split is laid out that way. See
/// `ConversationStore.rearrangeShownSplit(placing:at:)`. Only the pane's own window takes it, while no other window is in
/// front of it under the pointer.
@MainActor
final class SplitPaneDragToRearrange {
    static let shared = SplitPaneDragToRearrange()

    private struct Drag {
        let tabID: UUID
        let store: ConversationStore
        let place: TerminalDropPlace?
    }

    private var drag: Drag?
    private var splitDropTargets: TerminalSplitDropTargets { TabDragBetweenWindows.shared.splitDropTargets }

    private init() {}

    /// Follows the pointer, highlighting where the tab, which the highlight names `title`, would sit.
    func follow(_ tabID: UUID, titled title: String, in store: ConversationStore) {
        guard store.shownSplit?.contains(tabID) == true else { return cancel() }
        let place = placeOnTerminals(at: NSEvent.mouseLocation, in: store)
        drag = Drag(tabID: tabID, store: store, place: place)
        splitDropTargets.show(place.map { TerminalSplitDropTargets.Target(storeID: ObjectIdentifier(store), place: $0, title: title) })
    }

    /// Ends the drag, laying the split out where the pane was let go over the terminals, if it was.
    func drop() {
        defer { cancel() }
        guard let drag, let place = drag.place else { return }
        drag.store.rearrangeShownSplit(placing: drag.tabID, at: place)
    }

    /// Ends the drag of the tab's pane, if it goes on, leaving everything as it was.
    func cancel(_ tabID: UUID) {
        if drag?.tabID == tabID { cancel() }
    }

    private func cancel() {
        drag = nil
        splitDropTargets.show(nil)
    }

    private func placeOnTerminals(at pointer: CGPoint, in store: ConversationStore) -> TerminalDropPlace? {
        guard let window = store.windowRegistry.window(of: store),
              NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: 0) == window.windowNumber else { return nil }
        return splitDropTargets.place(at: pointer, in: store, windowFrame: window.frame, ignoringShownSplit: true)
    }
}

extension View {
    /// Lets a shown split's pane be dragged by this view, its mini toolbar, to another edge of the terminals; see
    /// `SplitPaneDragToRearrange`. A click still selects the pane's tab.
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
                    .onChanged { _ in SplitPaneDragToRearrange.shared.follow(tabID, titled: title, in: store) }
            )
            .onChange(of: isDragging) { _, isDragging in
                if !isDragging { SplitPaneDragToRearrange.shared.drop() }
            }
            .onDisappear { SplitPaneDragToRearrange.shared.cancel(tabID) }
    }
}
