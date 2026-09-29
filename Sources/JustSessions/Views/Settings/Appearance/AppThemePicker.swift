import SwiftUI

/// The themes, three to a row, each drawn as the window in that theme and the current appearance.
struct AppThemePicker: View {
    @ObservedObject var appThemeStore: AppThemeStore

    private let columns = Array(repeating: GridItem(.fixed(ThumbnailChoiceMetrics.buttonWidth), spacing: 14), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(AppTheme.allCases) { theme in
                ThumbnailChoiceButton(
                    title: theme.displayName,
                    isSelected: appThemeStore.theme == theme,
                    onSelect: { appThemeStore.setTheme(theme) }
                ) {
                    AppWindowSketch().environment(\.appTheme, theme)
                }
            }
        }
        // A settings grid can offer this block less than the cards need, and a squeezed card loses its name.
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Theme")
    }
}
