import SwiftUI

struct ArchivedProjectsSheet: View {
    let store: ConversationStore
    let host: SessionHost
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let archivedProjectPaths = store.archivedProjectPaths(on: host)
        ThemeSheetLayout(
            title: Text("Archived projects on \(host.nameInSentence)"),
            width: ThemeSheetMetrics.compactWidth
        ) {
            HelpPopoverButton(
                title: "Archived projects",
                explanation:
                    "An archived project is hidden from the sidebar. Its folder and sessions stay on disk, and restoring it lists them again. Starting a new session in its folder also restores it."
            )
            .accessibilityIdentifier("archivedProjects.help")
        } content: {
            if archivedProjectPaths.isEmpty {
                Text("No archived projects")
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                Group {
                    if archivedProjectPaths.count > 7 {
                        ScrollView { rows(archivedProjectPaths) }.frame(height: 300)
                    } else {
                        rows(archivedProjectPaths)
                    }
                }
                .background(ThemePalette.raisedSurface, in: RoundedRectangle(.card))
                .overlay(RoundedRectangle(.card).stroke(ThemePalette.hairline, lineWidth: 1))
            }
        } footer: {
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(ThemeProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
    }

    private func rows(_ archivedProjectPaths: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(archivedProjectPaths, id: \.self) { projectPath in
                row(for: projectPath)
                if projectPath != archivedProjectPaths.last {
                    ThemeDivider()
                }
            }
        }
    }

    private func row(for projectPath: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: store.projectDisplayName(forProjectPath: projectPath))
                    .font(ThemeFont.body.weight(.medium))
                    .lineLimit(1)
                Text(verbatim: ProjectLocation(key: projectPath).copyablePath)
                    .font(ThemeFont.detail)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button("Restore") { store.showProjectInSidebar(projectPath) }
                .controlSize(.small)
                .accessibilityLabel("Restore \(store.projectDisplayName(forProjectPath: projectPath))")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
