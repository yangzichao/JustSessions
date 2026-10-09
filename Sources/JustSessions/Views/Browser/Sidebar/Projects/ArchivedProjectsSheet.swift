import SwiftUI

/// Lists one host's archived projects so they can come back. Archiving only hides a project from the sidebar: its
/// folder, session files, names, and pins all stay, and restoring it lists them again.
struct ArchivedProjectsSheet: View {
    @ObservedObject var store: ConversationStore
    let host: SessionHost
    @Environment(\.dismiss) private var dismiss

    private var archivedProjectPaths: [String] {
        store.archivedProjectPaths(on: host)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Archived projects on \(host.nameInSentence)").font(.title3.weight(.semibold))
            Text("An archived project is hidden from the sidebar. Its folder and sessions stay on disk, and restoring it lists them again. Starting a new session in its folder also restores it.")
                .font(.callout)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if archivedProjectPaths.isEmpty {
                Text("No archived projects")
                    .font(.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                // A short list keeps the sheet tight; a long one scrolls instead of growing past the window.
                Group {
                    if archivedProjectPaths.count > 7 {
                        ScrollView { rows }.frame(height: 300)
                    } else {
                        rows
                    }
                }
                .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThemePalette.hairline, lineWidth: 1))
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(ThemePalette.contentSurface)
    }

    private var rows: some View {
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
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(verbatim: ProjectLocation(key: projectPath).copyablePath)
                    .font(.system(size: 11))
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
