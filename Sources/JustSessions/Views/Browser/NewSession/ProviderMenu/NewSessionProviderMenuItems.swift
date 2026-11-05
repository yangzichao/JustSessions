import SwiftUI

/// A menu's New session items: one per CLI found on the host, each with its icon, or, when none was found, a line
/// saying so. The project's New session menu and the tab's Split right and Split down menus list them alike.
struct NewSessionProviderMenuItems: View {
    let providers: [ConversationProvider]
    let host: SessionHost
    let onStart: (ConversationProvider) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        if providers.isEmpty {
            Text(NewSessionProviderAvailability.noCLIFoundMessage(on: host, language: AppInterfaceLanguage(identifier: locale.identifier)))
        }
        ForEach(providers) { provider in
            Button {
                onStart(provider)
            } label: {
                Label {
                    Text(provider.rawValue)
                } icon: {
                    provider.iconImage()
                }
            }
        }
    }
}
