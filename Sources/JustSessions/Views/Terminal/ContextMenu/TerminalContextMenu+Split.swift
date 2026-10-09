import AppKit

/// The split entries, as the tab's menu in the tab bar offers them: a submenu followed by a separator.
extension TerminalContextMenu {
    var splitItems: [NSMenuItem] {
        let perform = { (action: TerminalTabSplitAction) in
            store.performSplitAction(action, fromTab: tab.id, closeTab: onCloseTab)
        }
        switch store.splitMenu(forTab: tab.id) {
        case .addTabToNewSplit(let candidates):
            let item = submenuItem(
                title: localized("Add tab to new split view"),
                systemImage: "rectangle.split.2x1",
                items: candidates.map { candidate in
                    ActionMenuItem(title: candidate.menuTitle) { perform(.addToNewSplit(candidate.id)) }
                }
            )
            item.isEnabled = !candidates.isEmpty
            return [item, .separator()]
        case .arrangeSplit:
            let item = submenuItem(title: localized("Arrange split view"), systemImage: "rectangle.split.2x1", items: [
                ActionMenuItem(title: localized("Separate views"), systemImage: "arrow.up.left.and.arrow.down.right") {
                    perform(.separateViews)
                },
                .separator(),
                ActionMenuItem(title: localized("Close left view"), systemImage: "xmark") { perform(.closeView(.left)) },
                ActionMenuItem(title: localized("Close right view"), systemImage: "xmark") { perform(.closeView(.right)) },
                .separator(),
                ActionMenuItem(title: localized("Reverse views"), systemImage: "arrow.left.arrow.right") { perform(.reverseViews) },
            ])
            return [item, .separator()]
        case .newSplitWithSelectedTab, .moveIntoShownSplit, nil:
            // A terminal on screen is the selected tab's or in its split, so the entries for tabs off screen never
            // come up here.
            return []
        }
    }
}
