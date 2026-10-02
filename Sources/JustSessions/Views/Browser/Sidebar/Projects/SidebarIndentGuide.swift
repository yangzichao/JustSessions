import SwiftUI

extension View {
    /// A hairline under the project's chevron that ties its sessions to it. Each row under the project draws its own
    /// stretch, reaching across the gap below it to the next row, so the rows can sit in the lazy list one by one.
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
    /// The gap between sidebar rows, which the guide bridges.
    static let rowSpacing: CGFloat = 1
}
