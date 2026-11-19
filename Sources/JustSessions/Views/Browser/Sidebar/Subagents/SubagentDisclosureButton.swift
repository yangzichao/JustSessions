import SwiftUI

struct SubagentDisclosureButton: View {
    let isExpanded: Bool
    let subagentCount: Int
    let sessionTitle: String
    let indentLevel: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .font(ThemeFont.glyph(.small, weight: .bold))
                .foregroundStyle(ThemePalette.secondaryText)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(ThemeMotion.disclosure, value: isExpanded)
                .frame(width: SidebarSessionRowMetrics.indentStep, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .padding(.leading, SidebarSessionRowMetrics.leadingPadding(indentLevel: indentLevel) - SidebarSessionRowMetrics.indentStep)
        .help(isExpanded ? "Hide \(subagentCount) subagent sessions" : "Show \(subagentCount) subagent sessions")
        .accessibilityLabel(isExpanded ? "Hide subagent sessions of \(sessionTitle)" : "Show subagent sessions of \(sessionTitle)")
    }
}
