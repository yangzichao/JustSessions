import SwiftUI

struct ResizableSidebarLayout<Sidebar: View, Detail: View>: View {
    let isSidebarHidden: Bool
    let sidebar: Sidebar
    let detail: Detail

    private let minimumDetailWidth: CGFloat = 600
    private let dividerWidth: CGFloat = 1
    private let minimumSidebarWidthAtDefaultInterfaceSize: CGFloat = 200
    private let maximumSidebarWidthAtDefaultInterfaceSize: CGFloat = 480

    @AppStorage("conversationSidebarWidth") private var savedSidebarWidthAtDefaultInterfaceSize = 248.0
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
            let sidebarScaleNeverBelowDefaultSize = max(InterfaceScale.factor, CGFloat(InterfaceSizeStore.defaultScale))
            let minimumSidebarWidth = minimumSidebarWidthAtDefaultInterfaceSize * sidebarScaleNeverBelowDefaultSize
            let maximumSidebarWidth = max(
                minimumSidebarWidth,
                min(
                    maximumSidebarWidthAtDefaultInterfaceSize * sidebarScaleNeverBelowDefaultSize,
                    geometry.size.width - minimumDetailWidth - dividerWidth)
            )
            let savedSidebarWidth = CGFloat(savedSidebarWidthAtDefaultInterfaceSize) * sidebarScaleNeverBelowDefaultSize
            let sidebarWidth = min(
                max((draggingSidebarWidth ?? savedSidebarWidth).rounded(), minimumSidebarWidth),
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
                            savedSidebarWidthAtDefaultInterfaceSize = Double(newWidth / sidebarScaleNeverBelowDefaultSize)
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
