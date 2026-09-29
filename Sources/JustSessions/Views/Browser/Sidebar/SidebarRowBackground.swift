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
            .fill(fillStyle)
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(selectionStyle)
                        .frame(width: 3)
                        .padding(.vertical, 7)
                        .padding(.leading, 3)
                }
            }
    }

    private var selectionStyle: AnyShapeStyle {
        selectionTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(ThemePalette.ink)
    }

    private var fillStyle: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(selectionStyle.opacity(0.13)) }
        return isHovered ? AnyShapeStyle(ThemePalette.hoverFill) : AnyShapeStyle(Color.clear)
    }
}
