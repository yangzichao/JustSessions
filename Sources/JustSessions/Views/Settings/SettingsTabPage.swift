import SwiftUI

/// The size every Settings tab shares, and the margin around its content.
enum SettingsTabPageMetrics {
    /// Fits the Appearance tab, the tallest, without scrolling.
    static let size = CGSize(width: 540, height: 775)
    static let contentPadding: CGFloat = 24
}

/// One tab of the Settings window, at the size every tab shares, so the window keeps one size when you switch tabs or
/// a setting changes what a tab shows. Content taller than that, such as an import error below the terminal colors,
/// scrolls inside the tab.
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
