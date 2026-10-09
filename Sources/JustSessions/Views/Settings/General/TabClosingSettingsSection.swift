import SwiftUI

/// The closing part of the General tab: what closing a tab does when its CLI can keep running in tmux. Don't ask
/// again in the close dialog sets the same choice.
struct TabClosingSettingsSection: View {
    @ObservedObject var settingsStore: TabCloseChoiceSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Closing tabs")
                    .font(.subheadline.weight(.medium))
                SettingsHelpButton(
                    title: "Closing tabs",
                    explanation: "For tabs whose CLI can keep running in tmux. Don't ask again in the close dialog sets it too."
                )
                .accessibilityIdentifier("settings.help.closingTabs")
            }
            Picker("When you close a tab", selection: Binding(
                get: { settingsStore.choice },
                set: { settingsStore.setChoice($0) }
            )) {
                Text("Ask each time").tag(TabCloseChoice.askEachTime)
                Text("Keep running").tag(TabCloseChoice.keepRunning)
                Text("End session").tag(TabCloseChoice.endSession)
            }
            .fixedSize()
            .accessibilityIdentifier("settings.tabCloseChoice")
        }
    }
}
