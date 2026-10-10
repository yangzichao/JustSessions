import SwiftUI

/// The size every Settings page shares, and the margin around its content.
enum SettingsTabPageMetrics {
    /// Fits the General and Permissions pages without scrolling. The Appearance page, much taller, scrolls.
    static let size = CGSize(width: 540, height: 610)
    static let contentPadding: CGFloat = 24
}

/// One page of Settings, at the size every page shares, so the sheet keeps one size when you switch pages or a
/// setting changes what a page shows. Content taller than that, such as the Appearance page, scrolls inside the page.
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
