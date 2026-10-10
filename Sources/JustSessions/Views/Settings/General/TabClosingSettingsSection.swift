import SwiftUI

/// The closing part of the General tab: what closing a tab does when its CLI can keep running in tmux, and what closing
/// a plain terminal does. Don't ask again in the close dialog sets the same choices.
struct TabClosingSettingsSection: View {
    @ObservedObject var tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    @ObservedObject var plainTerminalCloseChoiceSettingsStore: PlainTerminalCloseChoiceSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Closing tabs")
                    .font(.subheadline.weight(.medium))
                HelpPopoverButton(
                    title: "Closing tabs",
                    explanation: "The CLI tab choice is for tabs whose CLI can keep running in tmux. A terminal's shell always ends with its tab. Don't ask again in the close dialog sets these too."
                )
                .accessibilityIdentifier("settings.help.closingTabs")
            }
            Picker("When you close a CLI tab", selection: Binding(
                get: { tabCloseChoiceSettingsStore.choice },
                set: { tabCloseChoiceSettingsStore.setChoice($0) }
            )) {
                Text("Ask each time").tag(TabCloseChoice.askEachTime)
                Text("Keep running").tag(TabCloseChoice.keepRunning)
                Text("End session").tag(TabCloseChoice.endSession)
            }
            .fixedSize()
            .accessibilityIdentifier("settings.tabCloseChoice")
            Picker("When you close a terminal", selection: Binding(
                get: { plainTerminalCloseChoiceSettingsStore.choice },
                set: { plainTerminalCloseChoiceSettingsStore.setChoice($0) }
            )) {
                Text("Ask each time").tag(PlainTerminalCloseChoice.askEachTime)
                Text("Close without asking").tag(PlainTerminalCloseChoice.closeWithoutAsking)
            }
            .fixedSize()
            .accessibilityIdentifier("settings.plainTerminalCloseChoice")
        }
    }
}
