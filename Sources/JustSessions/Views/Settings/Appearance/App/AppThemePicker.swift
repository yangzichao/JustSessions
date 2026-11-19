import SwiftUI

struct AppThemePicker: View {
    @ObservedObject var appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore

    private let columns = Array(repeating: GridItem(.fixed(ThumbnailChoiceMetrics.buttonWidth), spacing: 14), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(AppTheme.allCases) { theme in
                let resolvedTheme = appThemeStore.resolvedTheme(for: theme)
                ThumbnailChoiceButton(
                    title: LocalizedStringKey(theme.displayName),
                    isSelected: appThemeStore.theme == theme,
                    onSelect: {
                        AppThemeChooser(appThemeStore: appThemeStore, terminalAppearanceStore: terminalAppearanceStore)
                            .choose(theme)
                    },
                    detail: resolvedTheme.customization.isEmpty ? nil : "Customized"
                ) {
                    LightAndDarkWindowSketch().environment(\.appTheme, resolvedTheme)
                }
            }
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Theme")
    }
}
