import SwiftUI

/// The split view entries of a tab's menu, as Chrome's tab menu offers them, each a submenu but the first and each
/// followed by a separator. The selected tab in no split offers Split right and Split down instead of Chrome's Add tab to
/// new split view, each listing new sessions of its project's CLIs, a terminal, and the other tabs.
struct TerminalTabSplitMenuItems: View {
    /// Nil for no entries.
    let splitMenu: TerminalTabSplitMenu?
    let onSplitAction: (TerminalTabSplitAction) -> Void

    var body: some View {
        switch splitMenu {
        case .newSplitWithSelectedTab:
            Button("New split view with current tab", systemImage: "rectangle.split.2x1") {
                onSplitAction(.newSplitWithSelectedTab(.sideBySide))
            }
            Button("New split view below current tab", systemImage: "rectangle.split.1x2") {
                onSplitAction(.newSplitWithSelectedTab(.stacked))
            }
            Divider()
        case .addTabToNewSplit(let candidates, let providers, let canStartNewTabs):
            newSplitMenu(.sideBySide, candidates: candidates, providers: providers, canStartNewTabs: canStartNewTabs)
            newSplitMenu(.stacked, candidates: candidates, providers: providers, canStartNewTabs: canStartNewTabs)
            Divider()
        case .moveIntoShownSplit(let orientation):
            Menu {
                swapButton(orientation, .left)
                swapButton(orientation, .right)
            } label: {
                Label("Move tab into split view", systemImage: orientation.systemImage)
            }
            Divider()
        case .arrangeSplit(let orientation):
            Menu {
                Button("Separate views", systemImage: "arrow.up.left.and.arrow.down.right") {
                    onSplitAction(.separateViews)
                }
                Divider()
                if orientation == .sideBySide {
                    Button("Close left view", systemImage: "xmark") { onSplitAction(.closeView(.left)) }
                    Button("Close right view", systemImage: "xmark") { onSplitAction(.closeView(.right)) }
                } else {
                    Button("Close top view", systemImage: "xmark") { onSplitAction(.closeView(.left)) }
                    Button("Close bottom view", systemImage: "xmark") { onSplitAction(.closeView(.right)) }
                }
                Divider()
                Button("Reverse views", systemImage: orientation == .sideBySide ? "arrow.left.arrow.right" : "arrow.up.arrow.down") {
                    onSplitAction(.reverseViews)
                }
                if orientation == .sideBySide {
                    Button("Stack views", systemImage: "rectangle.split.1x2") { onSplitAction(.setOrientation(.stacked)) }
                } else {
                    Button("Place views side by side", systemImage: "rectangle.split.2x1") {
                        onSplitAction(.setOrientation(.sideBySide))
                    }
                }
            } label: {
                Label("Arrange split view", systemImage: orientation.systemImage)
            }
            Divider()
        case nil:
            EmptyView()
        }
    }

    /// Split right or Split down: a new session of each CLI and a terminal in the tab's project, then the other tabs.
    private func newSplitMenu(
        _ orientation: TerminalSplit.Orientation,
        candidates: [TerminalTabSplitCandidate],
        providers: [ConversationProvider],
        canStartNewTabs: Bool
    ) -> some View {
        Menu {
            Group {
                ForEach(providers) { provider in
                    Button {
                        onSplitAction(.openInNewSplit(.session(provider), orientation))
                    } label: {
                        Label {
                            Text(provider.rawValue)
                        } icon: {
                            provider.iconImage()
                        }
                    }
                }
                Button("Terminal", systemImage: "apple.terminal") {
                    onSplitAction(.openInNewSplit(.terminal, orientation))
                }
            }
            .disabled(!canStartNewTabs)
            if !candidates.isEmpty {
                Divider()
                ForEach(candidates) { candidate in
                    Button(candidate.menuTitle) { onSplitAction(.addToNewSplit(candidate.id, orientation)) }
                }
            }
        } label: {
            if orientation == .sideBySide {
                Label("Split right", systemImage: orientation.systemImage)
            } else {
                Label("Split down", systemImage: orientation.systemImage)
            }
        }
    }

    @ViewBuilder
    private func swapButton(_ orientation: TerminalSplit.Orientation, _ side: TerminalSplit.Side) -> some View {
        let systemImage = orientation.swapWithViewSystemImage(side)
        let action = { onSplitAction(.moveIntoShownSplit(swappingWith: side)) }
        switch (orientation, side) {
        case (.sideBySide, .left): Button("Swap with left view", systemImage: systemImage, action: action)
        case (.sideBySide, .right): Button("Swap with right view", systemImage: systemImage, action: action)
        case (.stacked, .left): Button("Swap with top view", systemImage: systemImage, action: action)
        case (.stacked, .right): Button("Swap with bottom view", systemImage: systemImage, action: action)
        }
    }
}
