import SwiftUI

/// Right side of the window: the tab bar while tabs are open, above the selected tab's terminal or, with no tab
/// selected, the selected session's preview. Every tab's terminal stays in the view tree; only the selected one
/// shows, or both halves of a split while a split tab is selected, side by side around a draggable gutter as in
/// Chrome's split view. A click in the pane whose tab is not selected selects it, bringing it the keyboard, and still
/// reaches its terminal, so scrolling and selecting text work there too; that pane is dimmed slightly. Every split's
/// tabs keep their panes' widths while another tab shows, so coming back resizes no terminal.
/// The tab bar runs up into the title bar beside the window buttons; with no tabs open, the title bar stays clear.
struct WorkspaceDetailView: View {
    @ObservedObject var store: ConversationStore
    let sessionSelection: SessionMultiSelection
    let isSidebarHidden: Bool
    let onRename: (Conversation) -> Void
    let onCloseTerminal: (UUID) -> Void
    let onDelete: (Conversation) -> Void

    @Environment(\.titleBarRow) private var titleBarRow
    /// Each split's leading pane share of its width, by split id; even until its divider is dragged.
    @State private var splitFractions: [UUID: CGFloat] = [:]

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
                let shownSplit = store.shownSplit
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
                        let isShown = isActive || shownSplit?.contains(session.id) == true
                        let split = store.split(containing: session.id)
                        let side = split.flatMap { store.sides(of: $0)?.side(of: session.id) }
                        let paneWidths = TerminalSplitLayout.paneWidths(
                            fraction: split.map(splitFraction(of:)) ?? TerminalSplitLayout.evenFraction,
                            totalWidth: geometry.size.width
                        )
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
                        .offset(x: side == .right ? paneWidths.leading + TerminalSplitLayout.dividerWidth : 0)
                    }

                    if let shownSplit {
                        let paneWidths = TerminalSplitLayout.paneWidths(fraction: splitFraction(of: shownSplit), totalWidth: geometry.size.width)
                        WorkspaceSplitDivider(fraction: splitFractionBinding(for: shownSplit), totalWidth: geometry.size.width)
                            .frame(height: geometry.size.height)
                            .padding(.leading, paneWidths.leading)
                    }
                }
            }
            .tabBarTerminalPalette(from: .shared)
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: store.terminalSplits.map(\.id)) { _, splitIDs in
            // Forget the dividers of splits that are gone.
            splitFractions = splitFractions.filter { splitIDs.contains($0.key) }
        }
    }

    private func splitFraction(of split: TerminalSplit) -> CGFloat {
        splitFractions[split.id] ?? TerminalSplitLayout.evenFraction
    }

    private func splitFractionBinding(for split: TerminalSplit) -> Binding<CGFloat> {
        Binding(get: { splitFraction(of: split) }, set: { splitFractions[split.id] = $0 })
    }

    private func paneWidth(of side: TerminalSplit.Side?, paneWidths: TerminalSplitLayout.PaneWidths, totalWidth: CGFloat) -> CGFloat {
        switch side {
        case .left: paneWidths.leading
        case .right: paneWidths.trailing
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
