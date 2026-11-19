import SwiftUI

struct SidebarEmptyHostNote: View {
    @Environment(\.locale) private var locale
    let message: SidebarEmptyHostMessage

    var body: some View {
        Group {
            if message.isFailure {
                Text(message.text).foregroundStyle(ThemePalette.warningText)
            } else if let localizedText = message.localizedText {
                Text(resourceWithChosenLocale(localizedText)).foregroundStyle(ThemePalette.secondaryText)
            }
        }
        .font(ThemeFont.callout)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }

    private func resourceWithChosenLocale(_ resource: LocalizedStringResource) -> LocalizedStringResource {
        var localizedResource = resource
        localizedResource.locale = locale
        return localizedResource
    }
}
