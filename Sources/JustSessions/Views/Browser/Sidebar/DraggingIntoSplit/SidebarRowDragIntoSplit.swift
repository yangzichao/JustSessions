import AppKit

@MainActor
final class SidebarRowDragIntoSplit {
    static let shared = SidebarRowDragIntoSplit()

    private struct Drag {
        let row: SidebarDraggedRow
        let store: ConversationStore
        let pointedPlace: TerminalDropPlace?
    }

    private var drag: Drag?
    private var splitDropTargets: TerminalSplitDropTargets { TabDragBetweenWindows.shared.splitDropTargets }

    private init() {}

    func follow(_ row: SidebarDraggedRow, titled title: String, in store: ConversationStore) {
        let pointedPlace = placeOnTerminals(at: NSEvent.mouseLocation, in: store)
        let place = pointedPlace.flatMap { store.dropPlace(for: row, at: $0) }
        drag = Drag(row: row, store: store, pointedPlace: place == nil ? nil : pointedPlace)
        splitDropTargets.show(place.map { TerminalSplitDropTargets.Target(storeID: ObjectIdentifier(store), place: $0, title: title) })
    }

    @discardableResult
    func drop() -> Bool {
        defer { cancel() }
        guard let drag, let pointedPlace = drag.pointedPlace else { return false }
        drag.store.showDroppedRow(drag.row, at: pointedPlace)
        return true
    }

    func cancel(_ row: SidebarDraggedRow) {
        if drag?.row == row { cancel() }
    }

    private func cancel() {
        drag = nil
        splitDropTargets.show(nil)
    }

    private func placeOnTerminals(at pointer: CGPoint, in store: ConversationStore) -> TerminalDropPlace? {
        guard let window = store.windowRegistry.window(of: store),
            NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: 0) == window.windowNumber
        else { return nil }
        return splitDropTargets.place(at: pointer, in: store, windowFrame: window.frame)
    }
}
