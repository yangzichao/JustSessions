import SwiftUI

struct WorkspaceDetailView: View {
    let store: ConversationStore
    let sessionSelection: SessionMultiSelection
    var transcriptMatchReveal: TranscriptMatchReveal? = nil
    let isSidebarHidden: Bool
    let onRename: (Conversation) -> Void
    let onNewSession: () -> Void
    let onNewSessionInSplitChooser: (UUID) -> Void
    let onCloseTerminal: (UUID) -> Void
    let onCloseTabGroup: ([UUID], _ projectName: String) -> Void
    let onDelete: (Conversation) -> Void

    @Environment(\.titleBarRow) private var titleBarRow
    @State private var splitFractions: [UUID: CGFloat] = [:]
    @StateObject private var hoverCards = TabHoverCardController()

    var body: some View {
        VStack(spacing: 0) {
            if store.terminalSessions.isEmpty {
                Color.clear.frame(height: titleBarRow.height)
            } else {
                WorkspaceTabBar(
                    store: store,
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
        .overlay { TabHoverCardOverlay(store: store, controller: hoverCards) }
        .background(TabHoverCardEventWatcher(controller: hoverCards))
        .background(TerminalFindShortcuts(selectedTabFind: store.selectedTerminal?.findState, onFind: findInSelectedTab))
        .background(
            TranscriptBookmarkTargetReporter(
                target: TerminalTabBookmarks(store: store).commandTarget,
                isActive: store.selectedTerminalID != nil && !store.selectsShownSplitChooser
            )
        )
        .onChange(of: store.terminalSplits.map(\.id) + store.terminalSplitChoosers.map(\.id)) { _, splitViewIDs in
            splitFractions = splitFractions.filter { splitViewIDs.contains($0.key) }
        }
        .onChange(of: store.stackedSplitViewIDs) { oldStackedIDs, newStackedIDs in
            for splitViewID in oldStackedIDs.symmetricDifference(newStackedIDs) { splitFractions[splitViewID] = nil }
        }
    }

    private func findInSelectedTab() {
        guard let tab = store.selectedTerminal else { return }
        switch TerminalFindTarget(tab: tab) {
        case .conversation(let conversation):
            SessionReadingWindowManager.shared.open(conversation, store: store, showingFind: true)
        case .terminal:
            tab.findState.show()
        }
    }

    private func splitFraction(ofSplitView id: UUID) -> CGFloat {
        splitFractions[id] ?? TerminalSplitLayout.evenFraction
    }

    private func splitFractionBinding(forSplitView id: UUID) -> Binding<CGFloat> {
        Binding(get: { splitFraction(ofSplitView: id) }, set: { splitFractions[id] = $0 })
    }

    private func shownSplitLayout(ofSplitView id: UUID) -> TerminalSplitDropArea.ShownSplit {
        TerminalSplitDropArea.ShownSplit(fraction: splitFraction(ofSplitView: id), orientation: store.orientation(ofSplitView: id))
    }

    private func splitFrames(ofSplitView id: UUID, size: CGSize) -> TerminalSplitLayout.Frames {
        TerminalSplitLayout.frames(fraction: splitFraction(ofSplitView: id), size: size, orientation: store.orientation(ofSplitView: id))
    }

    private func reverseShownSplitView() {
        if let shownSplit = store.shownSplit {
            store.reverseSplit(shownSplit.id)
        } else if let shownSplitChooser = store.shownSplitChooser {
            store.reverseSplitChooser(shownSplitChooser.id)
        }
    }

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

extension View {
    fileprivate func shown(_ isShown: Bool) -> some View {
        opacity(isShown ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
    }
}
