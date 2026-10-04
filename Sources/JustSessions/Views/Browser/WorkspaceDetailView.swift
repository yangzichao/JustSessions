import SwiftUI

/// Right side of the window: the tab bar while tabs are open, above the selected tab's terminal or, with no tab
/// selected, the selected session's preview. Every tab's terminal stays in the view tree; only the selected one
/// shows, or both halves of a split while a split tab is selected, side by side around a draggable gutter as in
/// Chrome's split view. A click in the pane whose tab is not selected selects it, bringing it the keyboard, and still
/// reaches its terminal, so scrolling and selecting text work there too; that pane is dimmed slightly. A split tab
/// keeps its pane's width while another tab shows, so coming back resizes no terminal.
/// The tab bar runs up into the title bar beside the window buttons; with no tabs open, the title bar stays clear.
struct WorkspaceDetailView: View {
    @ObservedObject var store: ConversationStore
    let sessionSelection: SessionMultiSelection
    let isSidebarHidden: Bool
    let onRename: (Conversation) -> Void
    let onCloseTerminal: (UUID) -> Void
    let onDelete: (Conversation) -> Void

    @Environment(\.titleBarRow) private var titleBarRow
    /// The leading pane's share of the split's width; even until the divider is dragged.
    @State private var splitFraction: CGFloat = TerminalSplitLayout.evenFraction

    var body: some View {
        VStack(spacing: 0) {
            if store.terminalSessions.isEmpty {
                Color.clear.frame(height: titleBarRow.height)
            } else {
                WorkspaceTabBar(
                    store: store,
                    // With the sidebar hidden, the bar's leading edge is the window's, under the window buttons.
                    leadingClearance: isSidebarHidden ? titleBarRow.toggleTrailingEdge : 0,
                    onRenameConversation: onRename,
                    onCloseTerminal: onCloseTerminal
                )
            }
            GeometryReader { geometry in
                let splitPair = store.terminalSplitPair
                let shownSplitPair = store.shownSplitPair
                let paneWidths = TerminalSplitLayout.paneWidths(fraction: splitFraction, totalWidth: geometry.size.width)
                ZStack(alignment: .topLeading) {
                    SessionPreviewPane(
                        store: store,
                        sessionSelection: sessionSelection,
                        onRename: onRename,
                        onDelete: onDelete
                    )
                    .shown(store.selectedTerminalID == nil)

                    ForEach(store.terminalSessions) { session in
                        let isActive = store.selectedTerminalID == session.id
                        let isShown = isActive || shownSplitPair?.contains(session.id) == true
                        let side = splitSide(of: session.id, in: splitPair)
                        TerminalWorkspaceView(
                            session: session,
                            isShown: isShown,
                            isActive: isActive,
                            onReconnect: session.host == .thisMac ? nil : { store.reconnectRemoteTerminal(session.id) },
                            onFocus: { store.selectTerminal(session.id) }
                        )
                        .overlay {
                            if isShown && !isActive { SplitPaneDimming() }
                        }
                        .shown(isShown)
                        .frame(width: paneWidth(of: side, paneWidths: paneWidths, totalWidth: geometry.size.width), height: geometry.size.height)
                        .offset(x: side == .trailing ? paneWidths.leading + TerminalSplitLayout.dividerWidth : 0)
                    }

                    if shownSplitPair != nil {
                        WorkspaceSplitDivider(fraction: $splitFraction, totalWidth: geometry.size.width)
                            .frame(height: geometry.size.height)
                            .padding(.leading, paneWidths.leading)
                    }
                }
            }
            .tabBarTerminalPalette(from: .shared)
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: store.terminalSplitPair) { oldPair, newPair in
            guard let newPair else { return }
            splitFraction = TerminalSplitLayout.fraction(splitFraction, afterPairChangeFrom: oldPair, to: newPair)
        }
    }

    private enum SplitSide {
        case leading, trailing
    }

    /// The tab's side of the split pair, kept while the pair is not shown, or nil for a tab outside it.
    private func splitSide(of tabID: UUID, in splitPair: TerminalSplitPair?) -> SplitSide? {
        if tabID == splitPair?.leadingID { return .leading }
        if tabID == splitPair?.trailingID { return .trailing }
        return nil
    }

    private func paneWidth(of side: SplitSide?, paneWidths: TerminalSplitLayout.PaneWidths, totalWidth: CGFloat) -> CGFloat {
        switch side {
        case .leading: paneWidths.leading
        case .trailing: paneWidths.trailing
        case nil: totalWidth
        }
    }
}

/// Sets the split pane whose tab is not selected back from the one with the keyboard. It darkens in the terminal's
/// colors, not the app's, so it reads on a dark terminal in a light window too; clicks pass through to the terminal.
private struct SplitPaneDimming: View {
    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(terminalPalette.isDark ? 0.25 : 0.06))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private extension View {
    /// Hides the view from sight, clicks, and VoiceOver while leaving it in the view tree.
    func shown(_ isShown: Bool) -> some View {
        opacity(isShown ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
    }
}
