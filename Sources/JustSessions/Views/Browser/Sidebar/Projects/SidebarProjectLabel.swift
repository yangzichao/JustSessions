import SwiftUI

struct SidebarProjectLabel: View {
    let project: ProjectConversationGroup
    let parentLabel: String?

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: project.isPinned ? "pin" : "folder")
                .font(ThemeFont.callout)
                .foregroundStyle(ThemePalette.secondaryText)
                .frame(width: InterfaceScale.points(16))
            VStack(alignment: .leading, spacing: 1) {
                Text(project.displayName)
                    .font(ThemeFont.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let parentLabel {
                    Text(parentLabel)
                        .font(ThemeFont.caption)
                        .foregroundStyle(ThemePalette.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
    }
}
