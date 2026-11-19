import SwiftUI

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
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance")
    }
}
