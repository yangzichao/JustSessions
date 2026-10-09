import SwiftUI

/// Chooses the terminal colors: the app theme's, a preset, or colors imported from iTerm2, which the menu beside it
/// imports.
struct TerminalColorSchemePicker: View {
    @ObservedObject var appearanceStore: TerminalAppearanceStore
    @State private var importError: TerminalColorsImportError?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Picker("Colors", selection: Binding(
                    get: { appearanceStore.preferences.colorChoice },
                    set: { appearanceStore.setColorChoice($0) }
                )) {
                    Text("Match app theme").tag(TerminalColorChoice.matchAppTheme)
                    Divider()
                    ForEach(TerminalColorPreset.allCases) { preset in
                        Text(verbatim: preset.displayName).tag(TerminalColorChoice.preset(preset))
                    }
                    if let importedColors = appearanceStore.preferences.importedColors {
                        Divider()
                        Text("\(importedColors.sourceName) (imported)").tag(TerminalColorChoice.imported)
                    }
                }
                .labelsHidden()

                TerminalColorsImportMenu { result in
                    switch result {
                    case .success(let importedColors):
                        importError = nil
                        appearanceStore.useImportedColors(importedColors)
                    case .failure(let error):
                        importError = error
                    }
                }
            }
            if let importError {
                Text(importError.localizedMessage)
                    .font(.caption)
                    .foregroundStyle(ThemePalette.errorText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
