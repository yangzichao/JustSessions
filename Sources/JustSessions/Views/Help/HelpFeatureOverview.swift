import SwiftUI

struct HelpFeatureOverview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you can do").font(.headline)
            Text("Supports " + ConversationProvider.allCases.map(\.rawValue).joined(separator: ", ") + ". Features vary by CLI; see the user guide for compatibility.")
                .font(.callout)
                .foregroundStyle(ThemePalette.secondaryText)

            HelpFeatureRow(title: "Find sessions", systemImage: "magnifyingglass",
                           detail: "Browse by host and project. Search project names, paths, session titles, or IDs.")
            HelpFeatureRow(title: "Read conversations", systemImage: "doc.text",
                           detail: "Select a session to preview it, or choose Read for a separate window. Find text, adjust its size, and copy code.")
            HelpFeatureRow(title: "Resume and start", systemImage: "terminal",
                           detail: "Double-click or choose Resume to continue in the original CLI. Start a new session or open a project's Terminal.")
            HelpFeatureRow(title: "Organize and share", systemImage: "folder",
                           detail: "Pin or rename sessions, fork supported conversations, copy or export Markdown, and delete old sessions.")
            HelpFeatureRow(title: "Keep work running", systemImage: "arrow.triangle.2.circlepath",
                           detail: "With tmux, choose Keep running when closing a tab, then select the session to reattach. Plain terminals end when closed.")
            HelpFeatureRow(title: "Make it yours", systemImage: "gearshape",
                           detail: "Open Settings for themes, appearance, terminal fonts, and local Claude Code or Codex notifications.")
        }
    }
}

private struct HelpFeatureRow: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.medium)
                Text(detail).foregroundStyle(ThemePalette.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
    }
}
