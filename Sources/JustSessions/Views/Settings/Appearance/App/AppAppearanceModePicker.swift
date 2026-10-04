import SwiftUI

/// System, Light, and Dark, each drawn as the window in the chosen theme.
struct AppAppearanceModePicker: View {
    @ObservedObject var appAppearanceStore: AppAppearanceStore

    var body: some View {
        HStack(spacing: 14) {
            ForEach(AppAppearanceMode.allCases) { mode in
                ThumbnailChoiceButton(
                    title: mode.localizedDisplayName,
                    isSelected: appAppearanceStore.mode == mode,
                    onSelect: { appAppearanceStore.setMode(mode) }
                ) {
                    AppAppearanceThumbnail(mode: mode)
                }
            }
        }
        // A settings grid can offer this row less than the cards need, and a squeezed card loses its name.
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance")
    }
}
