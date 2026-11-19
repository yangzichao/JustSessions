import SwiftUI

/// One host's name and what closing a CLI tab on it does, as a row of the closing section's grid, so the pickers line
/// up whatever the hosts' names.
struct HostTabCloseChoiceRow: View {
    let host: SessionHost
    @ObservedObject var tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore

    var body: some View {
        GridRow {
            hostName
            Picker(
                selection: Binding(
                    get: { tabCloseChoiceSettingsStore.choice(for: host) },
                    set: { tabCloseChoiceSettingsStore.setChoice($0, for: host) }
                )
            ) {
                Text("Ask each time").tag(TabCloseChoice.askEachTime)
                Text("Keep running").tag(TabCloseChoice.keepRunning)
                Text("End session").tag(TabCloseChoice.endSession)
            } label: {
                hostName
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    @ViewBuilder
    private var hostName: some View {
        if host == .thisMac { Text("This Mac") } else { Text(verbatim: host.displayName) }
    }

    private var accessibilityIdentifier: String {
        host.sshDestination.map { "settings.tabCloseChoice.ssh.\($0)" } ?? "settings.tabCloseChoice.thisMac"
    }
}
