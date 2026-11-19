import SwiftUI

/// An after-.sidebar group registered before TextZoomCommands' lands above its divider (checked against a menu dump).
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
