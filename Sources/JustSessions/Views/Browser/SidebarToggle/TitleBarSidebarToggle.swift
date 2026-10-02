import SwiftUI

extension View {
    /// Puts the sidebar toggle in the title bar, just right of the close, minimize, and zoom buttons, where it stays
    /// while the sidebar is hidden.
    func titleBarSidebarToggle(isSidebarHidden: Binding<Bool>) -> some View {
        modifier(TitleBarSidebarToggle(isSidebarHidden: isSidebarHidden))
    }
}

/// Full screen has no title bar, so there the content moves down by a title bar's height to leave the toggle a
/// strip of its own at the window's leading edge.
private struct TitleBarSidebarToggle: ViewModifier {
    @Binding var isSidebarHidden: Bool
    @State private var titleBarHeight = Self.standardTitleBarHeight

    private static let standardTitleBarHeight: CGFloat = 28
    private static let leadingInsetBesideWindowButtons: CGFloat = 78
    private static let leadingInsetInFullScreen: CGFloat = 12

    private var isFullScreen: Bool { titleBarHeight == 0 }

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.top, isFullScreen ? Self.standardTitleBarHeight : 0)
            .overlay(alignment: .topLeading) {
                SidebarToggleButton(isSidebarHidden: $isSidebarHidden)
                    .frame(height: isFullScreen ? Self.standardTitleBarHeight : titleBarHeight)
                    .padding(.leading, isFullScreen ? Self.leadingInsetInFullScreen : Self.leadingInsetBesideWindowButtons)
                    .ignoresSafeArea(edges: .top)
            }
            .background {
                // Measured outside the padding above, so it reads the window's own title bar.
                Color.clear
                    .ignoresSafeArea(edges: .top)
                    .onGeometryChange(for: CGFloat.self, of: \.safeAreaInsets.top) { titleBarHeight = $0 }
            }
    }
}
