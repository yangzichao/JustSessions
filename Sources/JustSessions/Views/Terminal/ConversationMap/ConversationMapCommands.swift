import SwiftUI

/// View → Show Conversation Map / Hide Conversation Map: a column beside every CLI tab's terminal that draws its whole
/// conversation, as Sublime Text's minimap does; see `ConversationMapColumn`. No shortcut: Sublime's minimap has none and
/// PRD-20 asks for none. Under Hide Sidebar: an after-.sidebar group registered before TextZoomCommands' lands above its
/// divider (checked against a menu dump).
struct ConversationMapCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @AppStorage(ConversationMapVisibility.userDefaultsKey) private var showsConversationMap = ConversationMapVisibility.isShownByDefault

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button(
                AppLocalization.string(
                    showsConversationMap ? "Hide Conversation Map" : "Show Conversation Map",
                    language: languageStore.language)
            ) {
                showsConversationMap.toggle()
            }
        }
    }
}
