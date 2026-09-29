import SwiftUI

/// The Appearance tab of Settings: System, Light, or Dark for the whole app, each shown as a sketch of the window.
struct AppAppearanceSettingsView: View {
    @ObservedObject var appAppearanceStore: AppAppearanceStore
    @ObservedObject var terminalAppearanceStore: TerminalAppearanceStore

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
            GridRow {
                Text("Appearance")
                HStack(spacing: 14) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        AppAppearanceOption(
                            mode: mode,
                            isSelected: appAppearanceStore.mode == mode,
                            onSelect: { appAppearanceStore.setMode(mode) }
                        )
                    }
                }
                // The grid offers this column less than the cards need, and a squeezed card loses its name.
                .fixedSize()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Appearance")
            }
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Text(terminalNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(width: 540, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Terminals can have colors of their own, so say whether they follow this choice.
    private var terminalNote: String {
        switch terminalAppearanceStore.preferences.mode {
        case .matchApp: "Terminals match the app unless you choose their colors in the Terminal tab."
        case .light: "Terminals stay light, as chosen in the Terminal tab."
        case .dark: "Terminals stay dark, as chosen in the Terminal tab."
        }
    }
}
