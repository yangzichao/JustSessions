import SwiftUI

/// Puts `SidebarRowBackground` behind a row that tracks the pointer on its own.
private struct SidebarRowHighlight: ViewModifier {
    let isSelected: Bool
    let selectionTint: Color?
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(SidebarRowBackground(isSelected: isSelected, isHovered: isHovered, selectionTint: selectionTint))
            .onHover { isHovered = $0 }
    }
}

extension View {
    func sidebarRowHighlight(isSelected: Bool, selectionTint: Color? = nil) -> some View {
        modifier(SidebarRowHighlight(isSelected: isSelected, selectionTint: selectionTint))
    }
}
