import SwiftUI

@MainActor
enum SettingsTabPageMetrics {
    static var size: CGSize { CGSize(width: InterfaceScale.points(540), height: 755) }
    nonisolated static let contentPadding: CGFloat = 24
}

struct SettingsTabPage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.vertical) {
            content()
                .padding(SettingsTabPageMetrics.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: SettingsTabPageMetrics.size.width, height: SettingsTabPageMetrics.size.height)
        .background(ThemePalette.contentSurface)
    }
}
