import AppKit

/// Follows a sidebar row dragged onto its window's terminals, which light up where it would show once let go, as for a
/// tab dragged from the tab bar, and shows it there when let go; see `ConversationStore.showDroppedRow(_:at:)`. Only
/// the row's own window takes it, while no other window is in front of it under the pointer.
@MainActor
final class SidebarRowDragIntoSplit {
    static let shared = SidebarRowDragIntoSplit()

    private struct Drag {
        let row: SidebarDraggedRow
        let store: ConversationStore
        /// Where a tab would show, let go at the pointer over the terminals, while the row would show there.
        let pointedPlace: TerminalDropPlace?
    }

    private var drag: Drag?
    private var splitDropTargets: TerminalSplitDropTargets { TabDragBetweenWindows.shared.splitDropTargets }

    private init() {}

    /// Follows the pointer, highlighting where the row, which the highlight names `title`, would show while it is over
    /// the terminals of the store's window.
    func follow(_ row: SidebarDraggedRow, titled title: String, in store: ConversationStore) {
        let pointedPlace = placeOnTerminals(at: NSEvent.mouseLocation, in: store)
        let place = pointedPlace.flatMap { store.dropPlace(for: row, at: $0) }
        drag = Drag(row: row, store: store, pointedPlace: place == nil ? nil : pointedPlace)
        splitDropTargets.show(place.map { TerminalSplitDropTargets.Target(storeID: ObjectIdentifier(store), place: $0, title: title) })
    }

    /// Ends the drag, showing the row where it was let go over the terminals, if it was. Returns whether it did.
    @discardableResult
    func drop() -> Bool {
        defer { cancel() }
        guard let drag, let pointedPlace = drag.pointedPlace else { return false }
        drag.store.showDroppedRow(drag.row, at: pointedPlace)
        return true
    }

    /// Ends the drag of `row`, if it goes on, leaving everything as it was.
    func cancel(_ row: SidebarDraggedRow) {
        if drag?.row == row { cancel() }
    }

    private func cancel() {
        drag = nil
        splitDropTargets.show(nil)
    }

    /// Where a tab let go at `pointer`, in screen coordinates, over the terminals of the store's window would show; nil
    /// off them, or while another window is in front there.
    private func placeOnTerminals(at pointer: CGPoint, in store: ConversationStore) -> TerminalDropPlace? {
        guard let window = store.windowRegistry.window(of: store),
            NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: 0) == window.windowNumber
        else { return nil }
        return splitDropTargets.place(at: pointer, in: store, windowFrame: window.frame)
    }
}
