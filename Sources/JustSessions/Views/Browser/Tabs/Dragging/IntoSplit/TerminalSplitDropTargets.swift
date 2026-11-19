import CoreGraphics
import Foundation

@MainActor
final class TerminalSplitDropTargets: ObservableObject {
    struct Target: Equatable {
        let storeID: ObjectIdentifier
        let place: TerminalDropPlace
        let title: String
    }

    @Published private(set) var shownTarget: Target?
    private var terminalFramesByStore: [ObjectIdentifier: CGRect] = [:]
    private var shownSplitsByStore: [ObjectIdentifier: TerminalSplitDropArea.ShownSplit] = [:]

    func reportTerminalFrame(_ frameInWindow: CGRect?, in store: ConversationStore) {
        terminalFramesByStore[ObjectIdentifier(store)] = frameInWindow
    }

    func reportShownSplit(_ shownSplit: TerminalSplitDropArea.ShownSplit?, in store: ConversationStore) {
        shownSplitsByStore[ObjectIdentifier(store)] = shownSplit
    }

    func place(
        at pointer: CGPoint,
        in store: ConversationStore,
        windowFrame: CGRect,
        ignoringShownSplit: Bool = false
    ) -> TerminalDropPlace? {
        let storeID = ObjectIdentifier(store)
        guard let terminalFrame = terminalFramesByStore[storeID] else { return nil }
        let area = TerminalSplitDropArea(frameInWindow: terminalFrame, shownSplit: shownSplitsByStore[storeID])
        return area.place(atScreenPoint: pointer, windowFrame: windowFrame, ignoringShownSplit: ignoringShownSplit)
    }

    func show(_ target: Target?) {
        if shownTarget != target { shownTarget = target }
    }
}
