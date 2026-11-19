import Foundation

struct ConversationTitleAliases: Equatable {
    static let userDefaultsKey = "conversationAliases"

    private(set) var customTitlesByConversationID: [String: String]

    init(customTitlesByConversationID: [String: String] = [:]) {
        self.customTitlesByConversationID = customTitlesByConversationID
    }

    static func load(from userDefaults: UserDefaults) -> ConversationTitleAliases {
        let storedTitles = userDefaults.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
        return ConversationTitleAliases(customTitlesByConversationID: storedTitles)
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(customTitlesByConversationID, forKey: Self.userDefaultsKey)
    }

    func title(for conversation: Conversation) -> String {
        customTitlesByConversationID[conversation.id] ?? conversation.suggestedTitle
    }

    mutating func rename(_ conversation: Conversation, to proposedTitle: String) {
        let trimmedTitle = proposedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty || trimmedTitle == conversation.suggestedTitle {
            customTitlesByConversationID.removeValue(forKey: conversation.id)
        } else {
            customTitlesByConversationID[conversation.id] = trimmedTitle
        }
    }

    mutating func removeTitle(forConversationID conversationID: String) {
        customTitlesByConversationID.removeValue(forKey: conversationID)
    }
}
