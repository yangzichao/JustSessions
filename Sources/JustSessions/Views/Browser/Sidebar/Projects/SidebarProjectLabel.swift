import SwiftUI

/// A project's icon and name, with its parent folder under the name when another project shares the name: in its row,
/// and in the ghost that follows the pointer while it is dragged.
struct SidebarProjectLabel: View {
    let project: ProjectConversationGroup
    let parentLabel: String?

    var body: some View {
        HStack(spacing: 7) {
            // A pinned project's pin takes the folder's place, rather than joining the status and actions at the end.
            Image(systemName: project.isPinned ? "pin.fill" : "folder")
                .font(.system(size: 12))
                .foregroundStyle(ThemePalette.secondaryText)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let parentLabel {
                    Text(parentLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(ThemePalette.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
    }
}
