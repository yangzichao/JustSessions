import SwiftUI

extension View {
    /// Reports where the window's terminals show, and how the split shown there lays out its panes, to
    /// `TabDragBetweenWindows`, so a tab dragged over them finds where it would show.
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
