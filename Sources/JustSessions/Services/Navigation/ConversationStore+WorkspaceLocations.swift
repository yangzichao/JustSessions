import Foundation

extension ConversationStore {
    func canShow(_ location: WorkspaceLocation, listedConversationIDs: Set<String>) -> Bool {
        switch location {
        case .tab(let tabID):
            terminalSessions.contains { $0.id == tabID }
        case .conversation(let conversationID):
            listedConversationIDs.contains(conversationID) || subagentIndex.subagent(withID: conversationID) != nil
        }
    }

    func areTabsOfOneSplit(_ previous: WorkspaceLocation?, _ location: WorkspaceLocation) -> Bool {
        guard case .tab(let previousTabID)? = previous, case .tab(let tabID) = location, previousTabID != tabID else {
            return false
        }
        return split(containing: tabID)?.contains(previousTabID) == true
    }

    func title(of location: WorkspaceLocation) -> String? {
        switch location {
        case .tab(let tabID):
            terminalSessions.first { $0.id == tabID }?.displayTitle
        case .conversation(let conversationID):
            conversation(withID: conversationID).map(title(for:))
        }
    }
}
