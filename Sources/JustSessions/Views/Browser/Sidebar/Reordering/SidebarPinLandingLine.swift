import SwiftUI

/// The line that shows where a dragged project or session would land, across the gap between two rows.
struct SidebarPinLandingLine: View {
    /// Lines a session's up with the sessions' icons rather than the project's chevron.
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
    /// Where a landing line in the scope starts: under a project's chevron, or before its sessions' icons.
    var landingLineLeadingInset: CGFloat {
        switch self {
        case .projects: 0
        case .sessions: SidebarSessionRowMetrics.leadingPadding(indentLevel: 0) - 4
        }
    }
}
