import AppKit

extension NewSessionProviderMenuItems {
    /// The same items for an AppKit menu, such as a terminal's.
    static func appKitItems(
        providers: [ConversationProvider],
        host: SessionHost,
        language: AppInterfaceLanguage,
        isEnabled: Bool,
        onStart: @escaping (ConversationProvider) -> Void
    ) -> [NSMenuItem] {
        guard !providers.isEmpty else {
            return [ActionMenuItem(title: NewSessionProviderAvailability.noCLIFoundMessage(on: host, language: language), isEnabled: false) {}]
        }
        return providers.map { provider in
            let item = ActionMenuItem(title: provider.rawValue, isEnabled: isEnabled) { onStart(provider) }
            item.image = provider.menuItemImage()
            return item
        }
    }
}
