import SwiftUI

extension View {
    func reportsTerminalSplitDropArea(in store: ConversationStore, shownSplit: TerminalSplitDropArea.ShownSplit?) -> some View {
        let splitDropTargets = TabDragBetweenWindows.shared.splitDropTargets
        return onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frameInWindow in
            splitDropTargets.reportTerminalFrame(frameInWindow, in: store)
        }
        .onChange(of: shownSplit, initial: true) { _, shownSplit in
            splitDropTargets.reportShownSplit(shownSplit, in: store)
        }
        .onDisappear {
            splitDropTargets.reportTerminalFrame(nil, in: store)
            splitDropTargets.reportShownSplit(nil, in: store)
        }
    }
}
