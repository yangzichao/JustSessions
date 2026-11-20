import SwiftUI

struct WorkspaceNavigationControls: ViewModifier {
    let store: ConversationStore
    @Binding var history: WorkspaceNavigationHistory
    @Binding var sessionSelection: SessionMultiSelection
    @Binding var isSidebarHidden: Bool
    let listedConversationIDs: Set<String>
    let isEnabled: Bool

    private var shownLocation: WorkspaceLocation? {
        WorkspaceLocation.shown(
            selectedTabID: store.selectedTerminalID,
            onlySelectedConversationID: sessionSelection.onlySelectedConversationID
        )
    }

    func body(content: Content) -> some View {
        let navigation = navigation
        content
            .titleBarControls(isSidebarHidden: $isSidebarHidden, navigation: navigation)
            .focusedSceneValue(\.workspaceNavigation, navigation)
            .onChange(of: shownLocation, initial: true) { previous, location in
                recordShownLocation(location, after: previous)
            }
    }

    private var navigation: WorkspaceNavigation {
        guard isEnabled else { return WorkspaceNavigation() }
        return WorkspaceNavigation(
            history: history,
            shown: shownLocation,
            store: store,
            listedConversationIDs: listedConversationIDs,
            go: show
        )
    }

    private func recordShownLocation(_ location: WorkspaceLocation?, after previous: WorkspaceLocation?) {
        guard let location else { return }
        if store.areTabsOfOneSplit(previous, location) {
            history.replaceCurrent(with: location)
        } else {
            history.record(location)
        }
    }

    private func show(_ destination: WorkspaceNavigation.Destination) {
        history.moveBeforeShowing(entryAt: destination.entryIndex)
        switch destination.location {
        case .tab(let tabID):
            store.selectTerminal(tabID)
        case .conversation(let conversationID):
            sessionSelection.selectOnly(conversationID)
            store.selectTerminal(nil)
        }
    }
}
