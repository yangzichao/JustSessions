import SwiftUI

/// The themes, three to a row, each drawn as the window in that theme, light and dark split on a slant, so a theme
/// shows both whatever the current appearance. Choosing one also gives terminals its colors.
struct AppThemePicker: View {
    @ObservedObject var appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore

    private let columns = Array(repeating: GridItem(.fixed(ThumbnailChoiceMetrics.buttonWidth), spacing: 14), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(AppTheme.allCases) { theme in
                ThumbnailChoiceButton(
                    title: LocalizedStringKey(theme.displayName),
                    isSelected: appThemeStore.theme == theme,
                    onSelect: {
                        AppThemeChooser(appThemeStore: appThemeStore, terminalAppearanceStore: terminalAppearanceStore)
                            .choose(theme)
                    }
                ) {
                    LightAndDarkWindowSketch().environment(\.appTheme, theme)
                }
            }
        }
        // A settings grid can offer this block less than the cards need, and a squeezed card loses its name.
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Theme")
    }
}
