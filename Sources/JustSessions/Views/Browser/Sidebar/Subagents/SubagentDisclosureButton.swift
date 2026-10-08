import SwiftUI

/// The chevron before a session's icon that shows or hides the sessions its subagents ran in. Laid over the row's
/// button, so a click on it doesn't also open the session.
struct SubagentDisclosureButton: View {
    let isExpanded: Bool
    let subagentCount: Int
    let sessionTitle: String
    /// The level of the row it sits on, 0 for a session.
    let indentLevel: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeOut(duration: 0.12), value: isExpanded)
                .frame(width: SidebarSessionRowMetrics.indentStep, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .padding(.leading, SidebarSessionRowMetrics.leadingPadding(indentLevel: indentLevel) - SidebarSessionRowMetrics.indentStep)
        .help(isExpanded ? "Hide \(subagentCount) subagent sessions" : "Show \(subagentCount) subagent sessions")
        .accessibilityLabel(isExpanded ? "Hide subagent sessions of \(sessionTitle)" : "Show subagent sessions of \(sessionTitle)")
    }
}
