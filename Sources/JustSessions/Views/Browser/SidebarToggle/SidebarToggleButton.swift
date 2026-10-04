import SwiftUI

/// The sidebar icon that hides or shows the sidebar, with a faint fill under the pointer.
struct SidebarToggleButton: View {
    static let width: CGFloat = 28

    @Binding var isSidebarHidden: Bool
    @State private var isHovered = false

    private var actionName: LocalizedStringKey {
        isSidebarHidden ? "Show sidebar" : "Hide sidebar"
    }

    private var helpText: LocalizedStringKey {
        isSidebarHidden ? "Show sidebar (⌃⌘S)" : "Hide sidebar (⌃⌘S)"
    }

    var body: some View {
        Button { isSidebarHidden.toggle() } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: Self.width, height: 22)
                .background {
                    if isHovered {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ThemePalette.hoverFill)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(helpText)
        .accessibilityLabel(actionName)
    }
}
