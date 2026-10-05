import SwiftUI

struct SidebarProjectSelectionActionBar: View {
    let selectedCount: Int
    let onRemove: () -> Void
    let onRemoveAndDeleteSessions: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("\(selectedCount) projects selected")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            Button(action: onRemove) {
                Label("Archive", systemImage: "archivebox")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Archive the selected projects; keep sessions and open terminals")
            .accessibilityLabel("Archive selected projects")
            Button(role: .destructive, action: onRemoveAndDeleteSessions) {
                Label("Archive and delete sessions…", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Archive the selected projects and delete their sessions, except those with open terminals")
            .accessibilityLabel("Archive selected projects and delete their sessions")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(ThemePalette.hoverFill)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(selectedCount) projects selected")
    }
}
