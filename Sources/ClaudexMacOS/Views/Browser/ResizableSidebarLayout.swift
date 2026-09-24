import SwiftUI

struct ResizableSidebarLayout<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail

    @AppStorage("conversationSidebarWidth") private var savedSidebarWidth = 248.0
    @State private var draggingSidebarWidth: CGFloat?

    init(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebar = sidebar()
        self.detail = detail()
    }

    var body: some View {
        GeometryReader { geometry in
            let maximumSidebarWidth = max(200, min(480, geometry.size.width - 608))
            let sidebarWidth = min(
                max(draggingSidebarWidth ?? CGFloat(savedSidebarWidth), 200),
                maximumSidebarWidth
            )

            HStack(spacing: 0) {
                sidebar.frame(width: sidebarWidth)

                SidebarResizeHandle(
                    width: sidebarWidth,
                    maximumWidth: maximumSidebarWidth,
                    onChange: { draggingSidebarWidth = $0 },
                    onCommit: { newWidth in
                        savedSidebarWidth = Double(newWidth)
                        draggingSidebarWidth = nil
                    }
                )

                detail.frame(minWidth: 600, maxWidth: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minWidth: 940, minHeight: 550)
    }
}
