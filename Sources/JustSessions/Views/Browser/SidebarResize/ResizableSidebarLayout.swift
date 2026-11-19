import SwiftUI

struct ResizableSidebarLayout<Sidebar: View, Detail: View>: View {
    let isSidebarHidden: Bool
    let sidebar: Sidebar
    let detail: Detail

    private let minimumDetailWidth: CGFloat = 600
    private let dividerWidth: CGFloat = 1

    @AppStorage("conversationSidebarWidth") private var savedSidebarWidth = 248.0
    @State private var draggingSidebarWidth: CGFloat?

    init(
        isSidebarHidden: Bool,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.isSidebarHidden = isSidebarHidden
        self.sidebar = sidebar()
        self.detail = detail()
    }

    var body: some View {
        GeometryReader { geometry in
            let interfaceScale = max(InterfaceScale.factor, 1)
            let minimumSidebarWidth = 200 * interfaceScale
            let maximumSidebarWidth = max(
                minimumSidebarWidth,
                min(480 * interfaceScale, geometry.size.width - minimumDetailWidth - dividerWidth)
            )
            let sidebarWidth = min(
                max((draggingSidebarWidth ?? CGFloat(savedSidebarWidth) * interfaceScale).rounded(), minimumSidebarWidth),
                maximumSidebarWidth
            ).rounded(.down)

            HStack(spacing: 0) {
                sidebar
                    .frame(width: sidebarWidth)
                    .frame(width: isSidebarHidden ? 0 : sidebarWidth, alignment: .trailing)
                    .opacity(isSidebarHidden ? 0 : 1)
                    .disabled(isSidebarHidden)
                    .accessibilityHidden(isSidebarHidden)

                if !isSidebarHidden {
                    Rectangle()
                        .fill(ThemePalette.hairline)
                        .background(ThemePalette.contentSurface)
                        .frame(width: dividerWidth)
                        .ignoresSafeArea(edges: .top)
                }

                detail.frame(minWidth: minimumDetailWidth, maxWidth: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .topLeading) {
                if !isSidebarHidden {
                    SidebarResizeHandle(
                        width: sidebarWidth,
                        minimumWidth: minimumSidebarWidth,
                        maximumWidth: maximumSidebarWidth,
                        onChange: { draggingSidebarWidth = $0 },
                        onCommit: { newWidth in
                            savedSidebarWidth = Double(newWidth / interfaceScale)
                            draggingSidebarWidth = nil
                        }
                    )
                    .padding(.leading, sidebarWidth)
                }
            }
        }
        .frame(minWidth: isSidebarHidden ? minimumDetailWidth : 940, minHeight: 550)
    }
}
