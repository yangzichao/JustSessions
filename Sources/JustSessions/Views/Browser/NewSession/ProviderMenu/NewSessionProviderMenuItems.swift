import SwiftUI

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
