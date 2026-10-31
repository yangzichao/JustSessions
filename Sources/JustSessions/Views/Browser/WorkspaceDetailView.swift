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
/// terminal. A tab dragged over the terminals lights up the pane it would take in a split; see
/// `TerminalSplitDropHighlight`. A split chooser lays out as a split's other view, its list in that pane; see
/// `TerminalSplitChooserPane`.
/// The tab bar runs up into the title bar beside the window buttons; with no tabs open, the title bar stays clear.
struct WorkspaceDetailView: View {
    let store: ConversationStore
    let sessionSelection: SessionMultiSelection
    var transcriptMatchReveal: TranscriptMatchReveal? = nil
    let isSidebarHidden: Bool
    let onRename: (Conversation) -> Void
    let onNewSession: () -> Void
    /// A split chooser's New Session…, whose tab takes the chooser's place.
    let onNewSessionInSplitChooser: (UUID) -> Void
    let onCloseTerminal: (UUID) -> Void
    let onCloseTabGroup: ([UUID], _ projectName: String) -> Void
    let onDelete: (Conversation) -> Void

    @Environment(\.titleBarRow) private var titleBarRow
    /// Each split's first pane share of the panes' width, or height when stacked, by split id: even until its resize area
    /// is dragged, and kept as
    /// its views are reversed or swapped, as Chrome keeps a split's sizes. A split chooser's is under its id, which the
    /// split takes once a tab is chosen.
    @State private var splitFractions: [UUID: CGFloat] = [:]
    @StateObject private var hoverCards = TabHoverCardController()

    var body: some View {
        VStack(spacing: 0) {
            if store.terminalSessions.isEmpty {
                Color.clear.frame(height: titleBarRow.height)
            } else {
                WorkspaceTabBar(
                    store: store,
                    // With the sidebar hidden, the bar's leading edge is the window's, under the title bar's controls.
                    leadingClearance: isSidebarHidden ? titleBarRow.controlsTrailingEdge : 0,
                    onRenameConversation: onRename,
                    onNewSession: onNewSession,
                    onCloseTerminal: onCloseTerminal,
                    onDeleteConversation: onDelete,
                    onCloseTabGroup: onCloseTabGroup
                )
                // Above the area below it, which sits in the title bar's safe area too, since the bar is shorter than
                // the title bar. A background there extends up through that safe area, as the preview's and a tab's
                // ended bar do, and it covered the bar whenever one of them showed.
                .zIndex(1)
            }
            GeometryReader { geometry in
                let shownSplit = store.shownSplit
                let shownSplitChooser = store.shownSplitChooser
                // The split, or split chooser, that shows, by the id its panes' widths are kept under.
                let shownSplitViewID = shownSplit?.id ?? shownSplitChooser?.id
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
                        .shown(shownSplitViewID != nil)

                    ForEach(store.terminalSessions) { session in
                        let isSelected = store.selectedTerminalID == session.id
                        let isShown = isSelected || shownSplit?.contains(session.id) == true
                        // Beside a split chooser that has the keyboard, the tab's terminal does not take it.
                        let isActive = isSelected && !(store.selectsShownSplitChooser && shownSplitChooser?.tabID == session.id)
                        let split = store.split(containing: session.id)
                        let splitChooser = store.splitChooser(beside: session.id)
                        let isInSplitView = split != nil || splitChooser != nil
                        let paneFrame = paneFrame(of: session.id, in: split, besideChooser: splitChooser, size: geometry.size)
                        TerminalWorkspaceView(
                            session: session,
                            isShown: isShown,
                            isActive: isActive,
                            onReconnect: session.host == .thisMac ? nil : { store.reconnectRemoteTerminal(session.id) },
                            onCheckHost: session.host == .thisMac ? nil : { store.checkHost(ofTerminal: session.id) },
                            hostProblem: { session.host.sshDestination.flatMap(store.hostCheckProblemMessage(on:)) },
                            onFocus: { store.selectTerminal(session.id) },
                            makeContextMenu: { linkUnderPointer in
                                TerminalContextMenu(
                                    store: store, tab: session, onRename: onRename, onCloseTab: onCloseTerminal, onDelete: onDelete,
                                    linkUnderPointer: linkUnderPointer
                                ).makeMenu()
                            },
                            onOpenLink: { link in TerminalLinkActions(store: store, tab: session).openClicked(link) },
                            store: store
                        )
                        // A split's terminal keeps its place inside the pane's outline, above the mini toolbar, while
                        // another tab shows too, so selecting another tab resizes no terminal.
                        .padding(isInSplitView ? WorkspaceSplitPaneMetrics.terminalInsets : EdgeInsets())
                        .overlay {
                            if isInSplitView && isShown {
                                WorkspaceSplitPaneOverlay(
                                    store: store,
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

                    if let shownSplitChooser {
                        let frames = splitFrames(ofSplitView: shownSplitChooser.id, size: geometry.size)
                        let chooserFrame = shownSplitChooser.side == .left ? frames.left : frames.right
                        TerminalSplitChooserPane(
                            store: store,
                            chooser: shownSplitChooser,
                            isSelected: store.selectsShownSplitChooser,
                            onNewSession: { onNewSessionInSplitChooser(shownSplitChooser.id) }
                        )
                        .id(shownSplitChooser.id)
                        .frame(width: chooserFrame.width, height: chooserFrame.height)
                        .offset(x: chooserFrame.minX, y: chooserFrame.minY)
                    }

                    if let shownSplitViewID {
                        let orientation = store.orientation(ofSplitView: shownSplitViewID)
                        let resizeAreaFrame = splitFrames(ofSplitView: shownSplitViewID, size: geometry.size).resizeArea
                        WorkspaceSplitResizeArea(
                            fraction: splitFractionBinding(forSplitView: shownSplitViewID),
                            totalLength: TerminalSplitLayout.totalLength(of: geometry.size, orientation),
                            orientation: orientation,
                            onReverse: reverseShownSplitView
                        )
                            .frame(width: resizeAreaFrame.width, height: resizeAreaFrame.height)
                            .offset(x: resizeAreaFrame.minX, y: resizeAreaFrame.minY)
                    }

                    TerminalSplitDropHighlight(
                        store: store,
                        area: TerminalSplitDropArea(
                            frameInWindow: CGRect(origin: .zero, size: geometry.size),
                            shownSplit: shownSplitViewID.map(shownSplitLayout(ofSplitView:))
                        )
                    )
                }
                .reportsTerminalSplitDropArea(in: store, shownSplit: shownSplitViewID.map(shownSplitLayout(ofSplitView:)))
            }
            .tabBarTerminalPalette(from: .shared, themeStore: .shared)
        }
        .ignoresSafeArea(edges: .top)
        .environment(\.tabHoverCards, hoverCards)
        // Over the terminals too, which the card hangs over from the tab bar.
        .overlay { TabHoverCardOverlay(store: store, controller: hoverCards) }
        .background(TabHoverCardEventWatcher(controller: hoverCards))
        .background(TerminalFindShortcuts(selectedTabFind: store.selectedTerminal?.findState, onFind: findInSelectedTab))
        // ⌘D, ⌘', and ⇧⌘' in the selected tab (TRM-74). The preview's reporter is active only while no tab is selected
        // (SessionPreviewPane), so one window never has two.
        .background(TranscriptBookmarkTargetReporter(
            target: TerminalTabBookmarks(store: store).commandTarget,
            isActive: store.selectedTerminalID != nil && !store.selectsShownSplitChooser
        ))
        .onChange(of: store.terminalSplits.map(\.id) + store.terminalSplitChoosers.map(\.id)) { _, splitViewIDs in
            // Forget the pane widths of splits and split choosers that are gone.
            splitFractions = splitFractions.filter { splitViewIDs.contains($0.key) }
        }
    }

    /// ⌘F in the selected tab: its conversation's Find in a reading window, or the tab's find bar; see
    /// `TerminalFindTarget`.
    private func findInSelectedTab() {
        guard let tab = store.selectedTerminal else { return }
        switch TerminalFindTarget(tab: tab) {
        case .conversation(let conversation):
            SessionReadingWindowManager.shared.open(conversation, store: store, showingFind: true)
        case .terminal:
            tab.findState.show()
        }
    }

    /// The split's, or split chooser's, left pane share, by its id.
    private func splitFraction(ofSplitView id: UUID) -> CGFloat {
        splitFractions[id] ?? TerminalSplitLayout.evenFraction
    }

    private func splitFractionBinding(forSplitView id: UUID) -> Binding<CGFloat> {
        Binding(get: { splitFraction(ofSplitView: id) }, set: { splitFractions[id] = $0 })
    }

    private func shownSplitLayout(ofSplitView id: UUID) -> TerminalSplitDropArea.ShownSplit {
        TerminalSplitDropArea.ShownSplit(fraction: splitFraction(ofSplitView: id), orientation: store.orientation(ofSplitView: id))
    }

    /// The split's, or split chooser's, panes and resize area in an area of `size`, side by side or stacked.
    private func splitFrames(ofSplitView id: UUID, size: CGSize) -> TerminalSplitLayout.Frames {
        TerminalSplitLayout.frames(fraction: splitFraction(ofSplitView: id), size: size, orientation: store.orientation(ofSplitView: id))
    }

    /// A double-click on the resize area reverses the shown split's views, or the shown split chooser and its tab.
    private func reverseShownSplitView() {
        if let shownSplit = store.shownSplit {
            store.reverseSplit(shownSplit.id)
        } else if let shownSplitChooser = store.shownSplitChooser {
            store.reverseSplitChooser(shownSplitChooser.id)
        }
    }

    /// Where the tab's terminal sits: its side's pane of its split, or the side a split chooser beside it leaves it, or
    /// the whole area for a tab in neither.
    private func paneFrame(of tabID: UUID, in split: TerminalSplit?, besideChooser chooser: TerminalSplitChooser?, size: CGSize) -> CGRect {
        let side: TerminalSplit.Side
        let splitViewID: UUID
        if let split, let splitSide = store.sides(of: split)?.side(of: tabID) {
            (side, splitViewID) = (splitSide, split.id)
        } else if let chooser {
            (side, splitViewID) = (chooser.tabSide, chooser.id)
        } else {
            return CGRect(origin: .zero, size: size)
        }
        let frames = splitFrames(ofSplitView: splitViewID, size: size)
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
