import SwiftUI

extension View {
    func sidebarIndentGuide(isFirstRow: Bool, isLastRow: Bool) -> some View {
        background(alignment: .leading) {
            Rectangle()
                .fill(ThemePalette.hairline)
                .frame(width: 1)
                .padding(.leading, 15)
                .padding(.top, isFirstRow ? 3 : 0)
                .padding(.bottom, isLastRow ? 3 : -SidebarIndentGuide.rowSpacing)
        }
    }
}

enum SidebarIndentGuide {
    static let rowSpacing: CGFloat = 1
}
