import SwiftUI

struct SidebarPinLandingLine: View {
    let leadingInset: CGFloat

    static let thickness: CGFloat = 2

    var body: some View {
        Capsule()
            .fill(ThemePalette.ink)
            .frame(height: Self.thickness)
            .padding(.leading, leadingInset)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension SidebarPinDrag.Scope {
    var landingLineLeadingInset: CGFloat {
        switch self {
        case .projects: 0
        case .sessions: SidebarSessionRowMetrics.leadingPadding(indentLevel: 0) - 4
        }
    }
}
