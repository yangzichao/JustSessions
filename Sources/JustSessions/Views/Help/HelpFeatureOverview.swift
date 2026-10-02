import SwiftUI

struct HelpFeatureOverview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you can do").font(.headline)
            Text(ConversationProvider.allCases.map(\.rawValue).joined(separator: ", ") + ". Support varies by CLI.")
                .font(.callout)
                .foregroundStyle(ThemePalette.secondaryText)

            HelpFeatureRow(title: "Find sessions", systemImage: "magnifyingglass",
                           detail: "Browse by host and project. Search projects, titles, paths, or IDs.")
            HelpFeatureRow(title: "Read conversations", systemImage: "doc.text",
                           detail: "Preview or choose Read. Find text, adjust size, and copy code.")
            HelpFeatureRow(title: "Resume and start", systemImage: "terminal",
                           detail: "Resume in the original CLI. Start sessions or project terminals.")
            HelpFeatureRow(title: "Organize and share", systemImage: "folder",
                           detail: "Pin, rename, fork, delete, and copy/export Markdown where supported.")
            HelpFeatureRow(title: "Keep work running", systemImage: "arrow.triangle.2.circlepath",
                           detail: "With tmux, choose Keep running and reattach later. Plain terminals end when closed.")
            HelpFeatureRow(title: "Make it yours", systemImage: "gearshape",
                           detail: "Settings: themes, appearance, terminal fonts, and local Claude/Codex notifications.")
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
