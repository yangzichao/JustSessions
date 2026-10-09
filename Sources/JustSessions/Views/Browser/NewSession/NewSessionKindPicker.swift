import SwiftUI

/// The host's CLIs, and under them a plain terminal, set apart because it runs no CLI. Both rows pick the same thing,
/// so choosing in one clears the other.
struct NewSessionKindPicker: View {
    @Binding var selection: NewSessionKind
    /// The tools installed on the selected host.
    let providers: [ConversationProvider]
    /// Shown in place of the tools when the host has none.
    let noCLIFoundMessage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Tool")
            VStack(alignment: .leading, spacing: 10) {
                if providers.isEmpty {
                    Label(noCLIFoundMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(ThemePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Picker("Tool", selection: $selection) {
                        ForEach(providers) { provider in
                            Text(provider.rawValue).tag(NewSessionKind.cli(provider))
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                HStack(spacing: 10) {
                    Picker("Terminal", selection: $selection) {
                        Text("Terminal").tag(NewSessionKind.plainTerminal)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    Text("Your login shell, with no CLI")
                        .font(.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                }
            }
        }
    }
}
