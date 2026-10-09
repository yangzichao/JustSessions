import SwiftUI

/// Puts `SidebarRowBackground` behind a row that tracks the pointer on its own.
private struct SidebarRowHighlight: ViewModifier {
    let isSelected: Bool
    let selectionProvider: ConversationProvider?
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(SidebarRowBackground(isSelected: isSelected, isHovered: isHovered, selectionProvider: selectionProvider))
            .onHover { isHovered = $0 }
    }
}

extension View {
    func sidebarRowHighlight(isSelected: Bool, selectionProvider: ConversationProvider? = nil) -> some View {
        modifier(SidebarRowHighlight(isSelected: isSelected, selectionProvider: selectionProvider))
    }
}
