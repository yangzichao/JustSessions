import SwiftUI

/// Right side of the window: the tab bar while tabs are open, above the selected tab's terminal or, with no tab
/// selected, the selected session's preview. Every tab's terminal stays in the view tree; only the selected one
/// shows, or both halves of a split while a split tab is selected, side by side around a draggable divider as in
/// Chrome's split view. Clicking the pane whose tab is not selected selects it, bringing it the keyboard.
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
    /// Where the divider sat as its drag began.
    @State private var splitDragStartFraction: CGFloat = TerminalSplitLayout.evenFraction

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
                        let placement = placement(of: session.id, in: shownSplitPair)
                        TerminalWorkspaceView(
                            session: session,
                            isActive: isActive,
                            onReconnect: session.host == .thisMac ? nil : { store.reconnectRemoteTerminal(session.id) }
                        )
                        .allowsHitTesting(isActive)
                        .overlay {
                            // The pane whose tab is not selected focuses on click, like an unfocused window;
                            // a slight tint sets it back from the pane with the keyboard.
                            if !isActive, placement == .leading || placement == .trailing {
                                SplitPaneFocusOverlay(onFocus: { store.selectTerminal(session.id) })
                            }
                        }
                        .opacity(placement == .hidden ? 0 : 1)
                        .accessibilityHidden(placement == .hidden)
                        .frame(width: paneWidth(of: placement, paneWidths: paneWidths, totalWidth: geometry.size.width), height: geometry.size.height)
                        .offset(x: placement == .trailing ? paneWidths.leading + TerminalSplitLayout.dividerWidth : 0)
                    }

                    if shownSplitPair != nil {
                        splitDivider(paneWidths: paneWidths, size: geometry.size)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: store.terminalSplitPair) { oldPair, newPair in
            guard let newPair, newPair != oldPair else { return }
            // Swapped panes keep their widths as they trade sides; a new pair starts even, as in Chrome.
            splitFraction = oldPair?.swapped == newPair ? 1 - splitFraction : TerminalSplitLayout.evenFraction
        }
    }

    /// The divider's thin line with its wider grab strip, between the split's panes.
    private func splitDivider(paneWidths: TerminalSplitLayout.PaneWidths, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(ThemePalette.hairline)
                .frame(width: TerminalSplitLayout.dividerWidth, height: size.height)
                .offset(x: paneWidths.leading)
            WorkspaceSplitDivider(
                onDragBegan: { splitDragStartFraction = splitFraction },
                onDragMoved: { delta in
                    splitFraction = TerminalSplitLayout.fraction(
                        startingAt: splitDragStartFraction,
                        draggedBy: delta,
                        totalWidth: size.width
                    )
                }
            )
            .frame(width: TerminalSplitLayout.dividerGrabWidth, height: size.height)
            .offset(x: paneWidths.leading - (TerminalSplitLayout.dividerGrabWidth - TerminalSplitLayout.dividerWidth) / 2)
        }
        .accessibilityElement()
        .accessibilityLabel("Split view divider")
        .accessibilityValue(Text(verbatim: "\(Int((splitFraction * 100).rounded()))%"))
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = direction == .increment ? 0.05 : -0.05
            splitFraction = TerminalSplitLayout.clampedFraction(splitFraction + step, totalWidth: size.width)
        }
    }

    private enum SplitPanePlacement {
        case hidden, full, leading, trailing
    }

    private func placement(of tabID: UUID, in shownSplitPair: TerminalSplitPair?) -> SplitPanePlacement {
        if let shownSplitPair {
            if tabID == shownSplitPair.leadingID { return .leading }
            if tabID == shownSplitPair.trailingID { return .trailing }
            return .hidden
        }
        return store.selectedTerminalID == tabID ? .full : .hidden
    }

    private func paneWidth(of placement: SplitPanePlacement, paneWidths: TerminalSplitLayout.PaneWidths, totalWidth: CGFloat) -> CGFloat {
        switch placement {
        case .leading: paneWidths.leading
        case .trailing: paneWidths.trailing
        case .full, .hidden: totalWidth
        }
    }
}

/// Lies over the split pane whose tab is not selected and takes the click that selects it, before the
/// terminal underneath can swallow it.
private struct SplitPaneFocusOverlay: View {
    let onFocus: () -> Void

    var body: some View {
        Rectangle()
            .fill(ThemePalette.hoverFill)
            .contentShape(Rectangle())
            // Focus moves on mouse down, as it does between windows, not on mouse up as a tap gesture would.
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in onFocus() })
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
