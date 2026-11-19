import SwiftUI

extension View {
    func titleBarControls(isSidebarHidden: Binding<Bool>, navigation: WorkspaceNavigation) -> some View {
        modifier(TitleBarControls(isSidebarHidden: isSidebarHidden, navigation: navigation))
    }
}

private struct TitleBarControls: ViewModifier {
    @Binding var isSidebarHidden: Bool
    let navigation: WorkspaceNavigation
    @State private var titleBarHeight = Self.standardTitleBarHeight

    private static let standardTitleBarHeight: CGFloat = 28
    private static let leadingInsetBesideWindowButtons: CGFloat = 78
    private static let leadingInsetInFullScreen: CGFloat = 12

    private var isFullScreen: Bool { titleBarHeight == 0 }

    private var controlsLeadingInset: CGFloat {
        isFullScreen ? Self.leadingInsetInFullScreen : Self.leadingInsetBesideWindowButtons
    }

    private var row: TitleBarRow {
        TitleBarRow(
            height: isFullScreen ? Self.standardTitleBarHeight : titleBarHeight,
            controlsTrailingEdge: controlsLeadingInset + SidebarToggleButton.width + WorkspaceNavigationButtons.width
        )
    }

    func body(content: Content) -> some View {
        let row = row
        content
            .safeAreaPadding(.top, isFullScreen ? Self.standardTitleBarHeight : 0)
            .environment(\.titleBarRow, row)
            .overlay(alignment: .topLeading) {
                HStack(spacing: 0) {
                    SidebarToggleButton(isSidebarHidden: $isSidebarHidden)
                    WorkspaceNavigationButtons(navigation: navigation)
                }
                .frame(height: row.height)
                .padding(.leading, controlsLeadingInset)
                .ignoresSafeArea(edges: .top)
            }
            .background {
                Color.clear
                    .ignoresSafeArea(edges: .top)
                    .onGeometryChange(for: CGFloat.self, of: \.safeAreaInsets.top) { titleBarHeight = $0 }
            }
    }
}
