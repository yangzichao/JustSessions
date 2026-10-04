import SwiftUI

struct ResizableSidebarLayout<Sidebar: View, Detail: View>: View {
    let isSidebarHidden: Bool
    let sidebar: Sidebar
    let detail: Detail

    private let minimumSidebarWidth: CGFloat = 200

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
            let maximumSidebarWidth = max(minimumSidebarWidth, min(480, geometry.size.width - 608))
            // Rounded so a saved fractional width or a fractional window-derived maximum cannot put the divider
            // and the sidebar's text on sub-pixel offsets.
            let sidebarWidth = min(
                max((draggingSidebarWidth ?? CGFloat(savedSidebarWidth)).rounded(), minimumSidebarWidth),
                maximumSidebarWidth
            ).rounded(.down)

            HStack(spacing: 0) {
                // A hidden sidebar stays in the view tree, past the window's leading edge, so it comes back with its
                // expanded projects and scroll position.
                sidebar
                    .frame(width: sidebarWidth)
                    .frame(width: isSidebarHidden ? 0 : sidebarWidth, alignment: .trailing)
                    .opacity(isSidebarHidden ? 0 : 1)
                    .disabled(isSidebarHidden)
                    .accessibilityHidden(isSidebarHidden)

                if !isSidebarHidden {
                    SidebarResizeHandle(
                        width: sidebarWidth,
                        minimumWidth: minimumSidebarWidth,
                        maximumWidth: maximumSidebarWidth,
                        onChange: { draggingSidebarWidth = $0 },
                        onCommit: { newWidth in
                            savedSidebarWidth = Double(newWidth)
                            draggingSidebarWidth = nil
                        }
                    )
                }

                detail.frame(minWidth: 600, maxWidth: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minWidth: isSidebarHidden ? 600 : 940, minHeight: 550)
    }
}
