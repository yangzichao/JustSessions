import SwiftUI

/// Fill behind a sidebar row: an accent tint when selected, a faint one under the pointer.
struct SidebarRowBackground: View {
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(fillColor)
    }

    private var fillColor: Color {
        if isSelected { return Color.accentColor.opacity(0.15) }
        return isHovered ? Color.primary.opacity(0.05) : .clear
    }
}

/// Puts `SidebarRowBackground` behind a row that tracks the pointer on its own.
private struct SidebarRowHighlight: ViewModifier {
    let isSelected: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(SidebarRowBackground(isSelected: isSelected, isHovered: isHovered))
            .onHover { isHovered = $0 }
    }
}

extension View {
    func sidebarRowHighlight(isSelected: Bool) -> some View {
        modifier(SidebarRowHighlight(isSelected: isSelected))
    }
}
