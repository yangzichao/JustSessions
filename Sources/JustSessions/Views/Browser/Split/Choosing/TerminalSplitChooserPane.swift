import SwiftUI

/// A split chooser's pane, as Chrome's split view new tab page: on the split area's background, inside a pane outline
/// that is darker while it has the keyboard, with a × in its top-trailing corner that closes it and a card listing the
/// tabs it can show; see `ConversationStore.splitChooserCandidates`. It takes the keyboard with the first tab
/// highlighted: ↑ and ↓ move the highlight, and Return or Space chooses that tab, as a click on a tab does. With no tab
/// to list, it offers New Session…, whose tab takes its place.
struct TerminalSplitChooserPane: View {
    let store: ConversationStore
    let chooser: TerminalSplitChooser
    /// The chooser has the keyboard.
    let isSelected: Bool
    let onNewSession: () -> Void

    @Environment(\.tabBarTerminalPalette) private var terminalPalette
    @FocusState private var hasKeyboard: Bool
    /// The tab ↑ and ↓ last moved to; the first listed while none is, or once it leaves the list.
    @State private var highlightedTabID: UUID?

    /// Chrome's list is at most 394 points wide, with 16 on either side.
    private static let listMaximumWidth: CGFloat = 394
    private static let listMargin: CGFloat = 16

    var body: some View {
        let candidates = store.splitChooserCandidates
        let highlightedTabID = highlightedTabID(among: candidates)
        ZStack(alignment: .topTrailing) {
            Group {
                if candidates.isEmpty {
                    TerminalSplitChooserEmptyState(orientation: store.orientation(ofSplitView: chooser.id), onNewSession: onNewSession)
                } else {
                    tabList(candidates, highlightedTabID: hasKeyboard ? highlightedTabID : nil)
                        .padding(.top, WorkspaceSplitPaneMetrics.miniToolbarHeight + Self.listMargin)
                        .padding([.horizontal, .bottom], Self.listMargin)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            closeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            WorkspaceSplitPaneOutlineShape(toolbarSize: .zero)
                .stroke(terminalPalette.splitPaneOutlineColor(isSelected: isSelected), lineWidth: WorkspaceSplitPaneMetrics.outlineWidth)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        // A click anywhere in the pane gives it the keyboard, as a click in a terminal's pane does.
        .contentShape(Rectangle())
        .onTapGesture { store.selectSplitChooser(beside: chooser.tabID) }
        .focusable()
        .focused($hasKeyboard)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { moveHighlight(by: -1, among: candidates) }
        .onKeyPress(.downArrow) { moveHighlight(by: 1, among: candidates) }
        .onKeyPress(.return) { chooseHighlightedTab(among: candidates) }
        .onKeyPress(.space) { chooseHighlightedTab(among: candidates) }
        .onChange(of: isSelected, initial: true) { _, isSelected in
            if isSelected { hasKeyboard = true }
        }
        .onChange(of: hasKeyboard) { _, hasKeyboard in
            if hasKeyboard && !isSelected { store.selectSplitChooser(beside: chooser.tabID) }
        }
        // It sits on the terminal's background, which can be dark in a light window or the reverse.
        .environment(\.colorScheme, terminalPalette.colorScheme)
    }

    private var closeButton: some View {
        let buttonSize = WorkspaceSplitPaneMetrics.miniToolbarButtonSize
        return Button { store.closeSplitChooser(chooser.id) } label: {
            Image(systemName: "xmark")
                .font(ThemeFont.glyph(.control, weight: .bold))
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Circle())
        }
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: nil))
        .foregroundStyle(ThemePalette.ink)
        .help("Close this view")
        .accessibilityLabel("Close this view")
        .padding(WorkspaceSplitPaneMetrics.outlineCornerRadius)
    }

    /// The card of tabs, as tall as its tabs until it fills the pane, then scrolling.
    private func tabList(_ candidates: [TerminalSession], highlightedTabID: UUID?) -> some View {
        let rows = LazyVStack(spacing: 0) {
            ForEach(candidates, id: \.id) { tab in
                TerminalSplitChooserRow(
                    tab: tab,
                    details: details(of: tab),
                    isHighlighted: tab.id == highlightedTabID,
                    onChoose: { store.chooseTab(tab.id, inSplitChooser: chooser.id) }
                )
                .id(tab.id)
            }
        }
        .padding(.vertical, 8)
        return ScrollViewReader { scrollProxy in
            ViewThatFits(in: .vertical) {
                rows
                ScrollView { rows }
            }
            .onChange(of: highlightedTabID) { _, highlightedTabID in
                if let highlightedTabID { scrollProxy.scrollTo(highlightedTabID) }
            }
        }
        .frame(maxWidth: Self.listMaximumWidth)
        .background(RoundedRectangle(.panel).fill(ThemePalette.hoverFill))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose a tab to add to split view")
    }

    /// Where the tab runs and what it runs, as its tab's hover card says: "JustSessions · Claude Code".
    private func details(of tab: TerminalSession) -> String {
        [
            store.projectDisplayName(forProjectPath: tab.projectDirectoryKey),
            store.hasRemoteHosts ? tab.host.displayName : nil,
            tab.provider?.rawValue ?? "Terminal",
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func highlightedTabID(among candidates: [TerminalSession]) -> UUID? {
        if let highlightedTabID, candidates.contains(where: { $0.id == highlightedTabID }) { return highlightedTabID }
        return candidates.first?.id
    }

    private func moveHighlight(by offset: Int, among candidates: [TerminalSession]) -> KeyPress.Result {
        guard let currentID = highlightedTabID(among: candidates),
              let currentIndex = candidates.firstIndex(where: { $0.id == currentID }) else { return .ignored }
        let nextIndex = min(max(currentIndex + offset, 0), candidates.count - 1)
        highlightedTabID = candidates[nextIndex].id
        return .handled
    }

    /// Chooses the highlighted tab, or, with none to list, opens New Session….
    private func chooseHighlightedTab(among candidates: [TerminalSession]) -> KeyPress.Result {
        guard let tabID = highlightedTabID(among: candidates) else {
            onNewSession()
            return .handled
        }
        store.chooseTab(tabID, inSplitChooser: chooser.id)
        return .handled
    }
}
