import SwiftUI

/// Fill behind a sidebar row: a wash of the row's CLI hue with a short bar at the leading edge when selected,
/// a faint ink one under the pointer. The wash is an opaque color the theme prepares (see
/// `AppThemeColors.selectedRowSurfaces`), so text on it stays as readable as the theme checked.
struct SidebarRowBackground: View {
    let isSelected: Bool
    let isHovered: Bool
    /// The CLI whose hue marks a selected row; rows without a CLI of their own fall back to ink.
    var selectionProvider: ConversationProvider? = nil

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
        selectionProvider.map { AnyShapeStyle($0.tintColor) } ?? AnyShapeStyle(ThemePalette.ink)
    }

    private var fillStyle: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(ThemeColor(role: .selectedRow(selectionProvider))) }
        return isHovered ? AnyShapeStyle(ThemePalette.hoverFill) : AnyShapeStyle(Color.clear)
    }
}
