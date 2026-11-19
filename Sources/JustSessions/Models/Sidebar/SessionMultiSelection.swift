struct SessionMultiSelection: Equatable {
    private(set) var selectedConversationIDs: Set<String> = []
    private(set) var anchorConversationID: String?

    var hasMultipleSelected: Bool { selectedConversationIDs.count > 1 }

    var onlySelectedConversationID: String? {
        selectedConversationIDs.count == 1 ? selectedConversationIDs.first : nil
    }

    func contains(_ conversationID: String) -> Bool {
        selectedConversationIDs.contains(conversationID)
    }

    mutating func selectOnly(_ conversationID: String) {
        selectedConversationIDs = [conversationID]
        anchorConversationID = conversationID
    }

    mutating func toggle(_ conversationID: String) {
        if selectedConversationIDs.remove(conversationID) == nil {
            selectedConversationIDs.insert(conversationID)
        }
        anchorConversationID = conversationID
    }

    mutating func selectRowShownThroughTabWhileNothingIsSelected(_ conversationIDShownThroughTab: String?) {
        guard selectedConversationIDs.isEmpty, let conversationIDShownThroughTab else { return }
        selectOnly(conversationIDShownThroughTab)
    }

    mutating func selectRange(to conversationID: String, in orderedConversationIDs: [String]) {
        guard let anchorConversationID,
            let anchorIndex = orderedConversationIDs.firstIndex(of: anchorConversationID),
            let targetIndex = orderedConversationIDs.firstIndex(of: conversationID)
        else {
            selectOnly(conversationID)
            return
        }
        let rangeBounds = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selectedConversationIDs = Set(orderedConversationIDs[rangeBounds])
    }

    mutating func clear() {
        selectedConversationIDs = []
        anchorConversationID = nil
    }

    mutating func keepOnly(_ availableConversationIDs: Set<String>) {
        selectedConversationIDs.formIntersection(availableConversationIDs)
        if let anchorConversationID, !availableConversationIDs.contains(anchorConversationID) {
            self.anchorConversationID = nil
        }
    }
}
