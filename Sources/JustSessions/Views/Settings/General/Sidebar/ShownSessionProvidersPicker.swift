import SwiftUI

/// **Show sessions from**: one box per CLI, all ticked by default, beside the label in two rows so General stays short.
/// Unticking one hides its sessions and stops New session offering it, in every window; see `HiddenConversationProviders`.
struct ShownSessionProvidersPicker: View {
    let store: ConversationStore

    private static let columnCount = 3
    private static var rows: [[ConversationProvider]] {
        let providers = ConversationProvider.allCases
        return stride(from: 0, to: providers.count, by: columnCount).map { start in
            Array(providers[start..<min(start + columnCount, providers.count)])
        }
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                GridRow(alignment: .firstTextBaseline) {
                    if index == 0 {
                        label
                    } else {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                    ForEach(row) { provider in
                        toggle(for: provider)
                    }
                }
            }
        }
    }

    private var label: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Show sessions from")
            HelpPopoverButton(
                title: "Hidden CLIs",
                explanation: "An unticked CLI's sessions leave the sidebar, search, and the filter menu, and New session stops offering it. Its open tabs stay, and its session files are kept."
            )
            .accessibilityIdentifier("settings.help.shownSessionProviders")
        }
    }

    private func toggle(for provider: ConversationProvider) -> some View {
        Toggle(isOn: Binding(
            get: { !store.hiddenConversationProviders.hides(provider) },
            set: { store.setHidden(!$0, provider: provider) }
        )) {
            Text(verbatim: provider.rawValue)
        }
        .fixedSize()
        .accessibilityIdentifier("settings.showsSessionsFrom.\(provider.executableName)")
    }
}
