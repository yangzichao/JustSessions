/// Finder-style session selection: a plain click selects one row, Command toggles a row,
/// and Shift selects the range between the anchor and the clicked row.
struct SessionMultiSelection: Equatable {
    private(set) var selectedConversationIDs: Set<String> = []
    /// Start of the next Shift-click range: the last row clicked without Shift.
    private(set) var anchorConversationID: String?

    var hasMultipleSelected: Bool { selectedConversationIDs.count > 1 }

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

    mutating func selectRange(to conversationID: String, in orderedConversationIDs: [String]) {
        guard let anchorConversationID,
              let anchorIndex = orderedConversationIDs.firstIndex(of: anchorConversationID),
              let targetIndex = orderedConversationIDs.firstIndex(of: conversationID) else {
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
