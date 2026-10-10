import SwiftUI

/// Right side of the window: the tab bar while tabs are open, above the selected tab's terminal or, with no tab
/// selected, the selected session's preview. Every tab's terminal stays in the view tree; only the selected one
/// shows, filling the area, or both views of a split while either of its tabs is selected, laid out as Chrome's split
/// view: in the terminals' background, each terminal inside a rounded outline with a mini toolbar in its corner, and a
/// resize area between them. Unlike Chrome, whose mini toolbar overlaps the page under it, each terminal ends above
/// its toolbar: a page scrolls and seldom puts anything in its bottom corner, but a terminal's last rows stay put and
/// hold the CLI's input and status. A click in the pane whose tab is not selected, or on its toolbar, selects that tab,
/// bringing it the keyboard, and a click in the pane still reaches its terminal, so scrolling and selecting text work
/// there too. Every split's tabs keep their terminals' sizes while another tab shows, so coming back resizes no
/// terminal.
/// The tab bar runs up into the title bar beside the window buttons; with no tabs open, the title bar stays clear.
struct WorkspaceDetailView: View {
    @ObservedObject var store: ConversationStore
    let sessionSelection: SessionMultiSelection
    var transcriptMatchReveal: TranscriptMatchReveal? = nil
    let isSidebarHidden: Bool
    let onRename: (Conversation) -> Void
    let onCloseTerminal: (UUID) -> Void
    let onDelete: (Conversation) -> Void

    @Environment(\.titleBarRow) private var titleBarRow
    /// Each split's left pane share of the panes' width, by split id: even until its resize area is dragged, and kept as
    /// its views are reversed or swapped, as Chrome keeps a split's sizes.
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
                // Above the area below it, which sits in the title bar's safe area too, since the bar is shorter than
                // the title bar. A background there extends up through that safe area, as the preview's and a tab's
                // ended bar do, and it covered the bar whenever one of them showed.
                .zIndex(1)
            }
            GeometryReader { geometry in
                let shownSplit = store.shownSplit
                ZStack(alignment: .topLeading) {
                    SessionPreviewPane(
                        store: store,
                        sessionSelection: sessionSelection,
                        transcriptMatchReveal: transcriptMatchReveal,
                        onRename: onRename,
                        onDelete: onDelete
                    )
                    .shown(store.selectedTerminalID == nil)

                    WorkspaceSplitAreaBackground()
                        .shown(shownSplit != nil)

                    ForEach(store.terminalSessions) { session in
                        let isActive = store.selectedTerminalID == session.id
                        let isShown = isActive || shownSplit?.contains(session.id) == true
                        let split = store.split(containing: session.id)
                        let paneFrame = paneFrame(of: session.id, in: split, size: geometry.size)
                        TerminalWorkspaceView(
                            session: session,
                            isShown: isShown,
                            isActive: isActive,
                            onReconnect: session.host == .thisMac ? nil : { store.reconnectRemoteTerminal(session.id) },
                            onFocus: { store.selectTerminal(session.id) },
                            makeContextMenu: {
                                TerminalContextMenu(store: store, tab: session, onRename: onRename, onCloseTab: onCloseTerminal).makeMenu()
                            }
                        )
                        // A split's terminal keeps its place inside the pane's outline, above the mini toolbar, while
                        // another tab shows too, so selecting another tab resizes no terminal.
                        .padding(split == nil ? EdgeInsets() : WorkspaceSplitPaneMetrics.terminalInsets)
                        .overlay {
                            if split != nil && isShown {
                                WorkspaceSplitPaneOverlay(
                                    session: session,
                                    isSelected: isActive,
                                    onSelect: { store.selectTerminal(session.id) },
                                    onClose: { onCloseTerminal(session.id) }
                                )
                            }
                        }
                        .shown(isShown)
                        .frame(width: paneFrame.width, height: paneFrame.height)
                        .offset(x: paneFrame.minX, y: paneFrame.minY)
                    }

                    if let shownSplit {
                        let resizeAreaFrame = TerminalSplitLayout.frames(fraction: splitFraction(of: shownSplit), size: geometry.size).resizeArea
                        WorkspaceSplitResizeArea(
                            fraction: splitFractionBinding(for: shownSplit),
                            totalWidth: geometry.size.width,
                            onReverse: { store.reverseSplit(shownSplit.id) }
                        )
                            .frame(width: resizeAreaFrame.width, height: resizeAreaFrame.height)
                            .offset(x: resizeAreaFrame.minX, y: resizeAreaFrame.minY)
                    }
                }
            }
            .tabBarTerminalPalette(from: .shared, themeStore: .shared)
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: store.terminalSplits.map(\.id)) { _, splitIDs in
            // Forget the pane widths of splits that are gone.
            splitFractions = splitFractions.filter { splitIDs.contains($0.key) }
        }
    }

    private func splitFraction(of split: TerminalSplit) -> CGFloat {
        splitFractions[split.id] ?? TerminalSplitLayout.evenFraction
    }

    private func splitFractionBinding(for split: TerminalSplit) -> Binding<CGFloat> {
        Binding(get: { splitFraction(of: split) }, set: { splitFractions[split.id] = $0 })
    }

    /// Where the tab's terminal sits: its side's pane of its split, or the whole area for a tab in no split.
    private func paneFrame(of tabID: UUID, in split: TerminalSplit?, size: CGSize) -> CGRect {
        guard let split, let side = store.sides(of: split)?.side(of: tabID) else { return CGRect(origin: .zero, size: size) }
        let frames = TerminalSplitLayout.frames(fraction: splitFraction(of: split), size: size)
        return side == .left ? frames.left : frames.right
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
