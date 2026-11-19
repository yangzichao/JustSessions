import SwiftUI

struct SidebarRowBackground: View {
    let isSelected: Bool
    let isHovered: Bool
    var selectionProvider: ConversationProvider? = nil

    var body: some View {
        RoundedRectangle(.control)
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
