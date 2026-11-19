import Foundation

protocol SavedCustomization: Equatable {
    static func load(from userDefaults: UserDefaults) -> Self
    func save(to userDefaults: UserDefaults)
}

extension ConversationTitleAliases: SavedCustomization {}
extension ProjectDisplayNames: SavedCustomization {}
extension PinnedItems: SavedCustomization {}
extension ArchivedSessions: SavedCustomization {}
extension MessageBookmarks: SavedCustomization {}
extension SessionsDeletedWhenTabCloses: SavedCustomization {}
extension HiddenConversationProviders: SavedCustomization {}
