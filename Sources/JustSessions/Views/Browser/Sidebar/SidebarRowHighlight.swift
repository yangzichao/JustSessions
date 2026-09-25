import SwiftUI

/// Fill behind a sidebar row: a wash of the row's CLI hue with a short bar at the leading edge when selected,
/// a faint ink one under the pointer.
struct SidebarRowBackground: View {
    let isSelected: Bool
    let isHovered: Bool
    /// The hue of a selected row; rows without a CLI of their own fall back to ink.
    var selectionTint: Color? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(fillColor)
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(selectionTint ?? ThemePalette.ink)
                        .frame(width: 3)
                        .padding(.vertical, 7)
                        .padding(.leading, 3)
                }
            }
    }

    private var fillColor: Color {
        if isSelected { return (selectionTint ?? ThemePalette.ink).opacity(0.13) }
        return isHovered ? ThemePalette.hoverFill : .clear
    }
}

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
