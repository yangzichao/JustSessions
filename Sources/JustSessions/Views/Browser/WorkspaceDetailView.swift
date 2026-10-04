import SwiftUI

/// Right side of the window: the tab bar while tabs are open, above the detail area's panes. Unsplit, the one
/// selection pane shows the selected tab's terminal or, with no tab selected, the selected session's preview —
/// and docked tabs get tiled panes beside it. Every tab's terminal stays in the view tree; an undocked,
/// unselected one is hidden at the selection pane's size, so it is laid out when it comes back.
struct WorkspaceDetailView: View {
    @ObservedObject var store: ConversationStore
    let sessionSelection: SessionMultiSelection
    let onRename: (Conversation) -> Void
    let onCloseTerminal: (UUID) -> Void
    let onDelete: (Conversation) -> Void

    @State private var tabDrag: TabDrag?
    /// One store for every preview pane, so each previewed session keeps its reading position by id.
    @State private var panePositionStore = TranscriptReadingPositionStore()
    /// The pane area's frame in `WorkspacePaneDropZone.coordinateSpaceName`, where tab drags are reported.
    @State private var paneAreaFrame = CGRect.zero

    private struct TabDrag: Equatable {
        var terminalID: UUID
        var location: CGPoint
    }

    var body: some View {
        VStack(spacing: 0) {
            if !store.terminalSessions.isEmpty {
                WorkspaceTabBar(
                    store: store,
                    onRenameConversation: onRename,
                    onCloseTerminal: onCloseTerminal,
                    onTabDragChanged: { id, location in tabDrag = TabDrag(terminalID: id, location: location) },
                    onTabDragEnded: { id, location in completeTabDrag(id, at: location) }
                )
                ThemeDivider()
            }
            GeometryReader { geometry in
                // Whole points, so pane edges and divider hairlines sit on the pixel grid.
                let bounds = CGRect(
                    origin: .zero,
                    size: CGSize(width: geometry.size.width.rounded(.down), height: geometry.size.height.rounded(.down))
                )
                let resolution = WorkspacePaneGeometry.resolve(store.paneLayout, in: bounds)
                let selectionRect = resolution.paneRects[.selection] ?? bounds

                ZStack(alignment: .topLeading) {
                    SessionPreviewPane(
                        store: store,
                        sessionSelection: sessionSelection,
                        onRename: onRename,
                        onDelete: onDelete
                    )
                    .paneFramed(selectionRect, shown: selectionPaneTerminalID == nil)

                    ForEach(store.terminalSessions) { session in
                        let dockedRect = resolution.paneRects[.terminal(session.id)]
                        let isVisible = dockedRect != nil || selectionPaneTerminalID == session.id
                        TerminalWorkspaceView(
                            session: session,
                            projectDisplayName: store.projectDisplayName(forProjectPath: session.projectDirectoryKey),
                            hostDisplayName: store.hasRemoteHosts ? session.host.displayName : nil,
                            isVisible: isVisible,
                            isFocused: isTerminalFocused(session.id, isDocked: dockedRect != nil),
                            onFocus: {
                                store.focusPane(dockedRect != nil ? .terminal(session.id) : .selection)
                                // A restored tab in a docked pane waits like a hidden tab; clicking it starts it,
                                // as selecting a waiting tab in the tab bar does.
                                if dockedRect != nil { session.startNowThatItIsShown() }
                            },
                            onReconnect: session.host == .thisMac ? nil : { store.reconnectRemoteTerminal(session.id) }
                        )
                        .paneFramed(dockedRect ?? selectionRect, shown: isVisible)
                    }

                    ForEach(previewPaneIDs(in: resolution), id: \.self) { conversationID in
                        if let rect = resolution.paneRects[.preview(conversationID)] {
                            WorkspacePreviewPane(
                                store: store,
                                conversationID: conversationID,
                                readingPositionStore: panePositionStore
                            )
                            .paneFramed(rect, shown: true)
                            .simultaneousGesture(TapGesture().onEnded { store.focusPane(.preview(conversationID)) })
                        }
                    }

                    ForEach(resolution.dividers, id: \.splitIndex) { divider in
                        WorkspacePaneDivider(divider: divider) { fraction in
                            store.setPaneFraction(fraction, atSplitIndex: divider.splitIndex)
                        }
                        .frame(width: divider.rect.width, height: divider.rect.height)
                        .position(x: divider.rect.midX, y: divider.rect.midY)
                    }

                    if let highlight = dropHighlightRect(in: resolution) {
                        WorkspacePaneDropHighlight()
                            .frame(width: highlight.width, height: highlight.height)
                            .position(x: highlight.midX, y: highlight.midY)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .onAppear { paneAreaFrame = geometry.frame(in: .named(WorkspacePaneDropZone.coordinateSpaceName)) }
                .onChange(of: geometry.frame(in: .named(WorkspacePaneDropZone.coordinateSpaceName))) { _, frame in
                    paneAreaFrame = frame
                }
            }
        }
        .coordinateSpace(name: WorkspacePaneDropZone.coordinateSpaceName)
    }

    private func previewPaneIDs(in resolution: WorkspacePaneGeometry.Resolution) -> [String] {
        resolution.paneRects.keys
            .compactMap { content -> String? in
                if case .preview(let id) = content { return id }
                return nil
            }
            .sorted()
    }

    /// The selected tab, when it shows in the selection pane rather than a pane of its own.
    private var selectionPaneTerminalID: UUID? {
        guard let selectedID = store.selectedTerminalID,
              !store.paneLayout.contains(.terminal(selectedID)) else { return nil }
        return selectedID
    }

    /// Keystrokes go to the focused pane's terminal: a docked tab's when its pane is focused, and otherwise the
    /// selected tab's, exactly as without splits.
    private func isTerminalFocused(_ id: UUID, isDocked: Bool) -> Bool {
        if isDocked { return store.focusedPaneContent == .terminal(id) }
        return store.selectedTerminalID == id && store.focusedPaneContent == .selection
    }

    // MARK: - Dragging a tab into a pane

    /// The hovered drop zone's highlight, shown only where releasing would actually change the layout.
    private func dropHighlightRect(in resolution: WorkspacePaneGeometry.Resolution) -> CGRect? {
        guard let tabDrag,
              let target = dropTarget(at: tabDrag.location, in: resolution),
              dropWouldChangeLayout(.terminal(tabDrag.terminalID), target: target),
              let paneRect = resolution.paneRects[target.content] else { return nil }
        return target.zone.highlightRect(in: paneRect)
    }

    private func dropTarget(
        at location: CGPoint,
        in resolution: WorkspacePaneGeometry.Resolution
    ) -> (content: WorkspacePaneContent, zone: WorkspacePaneDropZone)? {
        let local = CGPoint(x: location.x - paneAreaFrame.minX, y: location.y - paneAreaFrame.minY)
        return WorkspacePaneDropZone.target(at: local, in: resolution)
    }

    private func dropWouldChangeLayout(
        _ content: WorkspacePaneContent,
        target: (content: WorkspacePaneContent, zone: WorkspacePaneDropZone)
    ) -> Bool {
        switch target.zone {
        case .edge(let edge): store.paneLayout.docking(content, on: edge, of: target.content) != store.paneLayout
        case .center: store.paneLayout.movingToCenter(content, of: target.content) != store.paneLayout
        }
    }

    /// Releasing over a pane docks or moves the tab; anywhere else, nothing changes.
    private func completeTabDrag(_ id: UUID, at location: CGPoint) {
        defer { tabDrag = nil }
        let bounds = CGRect(
            origin: .zero,
            size: CGSize(width: paneAreaFrame.width.rounded(.down), height: paneAreaFrame.height.rounded(.down))
        )
        let resolution = WorkspacePaneGeometry.resolve(store.paneLayout, in: bounds)
        guard let target = dropTarget(at: location, in: resolution) else { return }
        switch target.zone {
        case .edge(let edge): store.dockPane(.terminal(id), on: edge, of: target.content)
        case .center: store.movePaneContent(.terminal(id), onto: target.content)
        }
    }
}

/// The drop zone a dragged tab is over: the half of the pane it would take, or the whole pane for a move.
struct WorkspacePaneDropHighlight: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.accentColor.opacity(0.16))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 2))
            .padding(2)
    }
}

private extension View {
    func paneFramed(_ rect: CGRect, shown isShown: Bool) -> some View {
        frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .shown(isShown)
    }

    /// Hides the view from sight, clicks, and VoiceOver while leaving it in the view tree.
    func shown(_ isShown: Bool) -> some View {
        opacity(isShown ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
    }
}
