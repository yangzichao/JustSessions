import AppKit

/// The split entries, as the tab's menu in the tab bar offers them: submenus followed by a separator.
extension TerminalContextMenu {
    var splitItems: [NSMenuItem] {
        let perform = { (action: TerminalTabSplitAction) in
            store.performSplitAction(action, fromTab: tab.id, closeTab: onCloseTab)
        }
        switch store.splitMenu(forTab: tab.id) {
        case .addTabToNewSplit(let candidates, let providers, let canStartNewTabs):
            let newSplitItems = [TerminalSplit.Orientation.sideBySide, .stacked].map { orientation in
                newSplitItem(orientation, candidates: candidates, providers: providers, canStartNewTabs: canStartNewTabs, perform: perform)
            }
            return newSplitItems + [.separator()]
        case .arrangeSplit(let orientation):
            let item = submenuItem(title: localized("Arrange split view"), systemImage: orientation.systemImage, items: [
                ActionMenuItem(title: localized("Separate views"), systemImage: "arrow.up.left.and.arrow.down.right") {
                    perform(.separateViews)
                },
                .separator(),
                ActionMenuItem(title: localized(orientation.closeViewTitle(.left)), systemImage: "xmark") { perform(.closeView(.left)) },
                ActionMenuItem(title: localized(orientation.closeViewTitle(.right)), systemImage: "xmark") { perform(.closeView(.right)) },
                .separator(),
                ActionMenuItem(
                    title: localized("Reverse views"),
                    systemImage: orientation == .sideBySide ? "arrow.left.arrow.right" : "arrow.up.arrow.down"
                ) { perform(.reverseViews) },
                ActionMenuItem(title: localized(orientation.toggleTitle), systemImage: orientation.toggled.systemImage) {
                    perform(.setOrientation(orientation.toggled))
                },
            ])
            return [item, .separator()]
        case .newSplitWithSelectedTab, .moveIntoShownSplit, nil:
            // A terminal on screen is the selected tab's or in its split, so the entries for tabs off screen never
            // come up here.
            return []
        }
    }

    /// Split right or Split down: a new session of each CLI and a terminal in the tab's project, then the other tabs.
    private func newSplitItem(
        _ orientation: TerminalSplit.Orientation,
        candidates: [TerminalTabSplitCandidate],
        providers: [ConversationProvider],
        canStartNewTabs: Bool,
        perform: @escaping (TerminalTabSplitAction) -> Void
    ) -> NSMenuItem {
        let newTabItems: [NSMenuItem] = providers.map { provider in
            ActionMenuItem(title: provider.rawValue, isEnabled: canStartNewTabs) {
                perform(.openInNewSplit(.session(provider), orientation))
            }
        } + [
            ActionMenuItem(title: localized("Terminal"), systemImage: "apple.terminal", isEnabled: canStartNewTabs) {
                perform(.openInNewSplit(.terminal, orientation))
            },
        ]
        let tabItems: [NSMenuItem] = candidates.map { candidate in
            ActionMenuItem(title: candidate.menuTitle) { perform(.addToNewSplit(candidate.id, orientation)) }
        }
        return submenuItem(
            title: localized(orientation.newSplitTitle),
            systemImage: orientation.systemImage,
            items: tabItems.isEmpty ? newTabItems : newTabItems + [.separator()] + tabItems
        )
    }
}
