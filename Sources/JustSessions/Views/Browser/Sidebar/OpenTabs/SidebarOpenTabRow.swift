import SwiftUI

/// An open tab: its tool's icon, the tab's title, and its CLI's status, highlighted while the tab is selected.
struct SidebarOpenTabRow: View {
    @ObservedObject var tab: TerminalSession
    let projectDisplayName: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    static let height: CGFloat = 44

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                toolIcon
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: tab.displayTitle)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    Text(verbatim: projectContext)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .truncationMode(.tail)
                Spacer(minLength: 6)
                TerminalStatusIndicator(session: tab)
            }
            .padding(.horizontal, 10)
            .frame(height: Self.height)
            .contentShape(Rectangle())
            .sidebarRowHighlight(isSelected: isSelected, selectionTint: tab.provider?.tintColor)
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .help(Text("Show \(tab.displayTitle)") + Text(verbatim: "\n" + projectContext + "\n" + tab.projectPath))
        .accessibilityLabel(Text(verbatim: "\(tab.displayTitle), \(projectContext)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            if tab.isPlainTerminal {
                Button("Close terminal…", systemImage: "xmark", role: .destructive, action: onClose)
            } else {
                Button("End session…", systemImage: "xmark", role: .destructive, action: onClose)
            }
        }
    }

    private var projectContext: String {
        if let destination = tab.host.sshDestination {
            return "\(projectDisplayName) · \(destination)"
        }
        return projectDisplayName
    }

    @ViewBuilder
    private var toolIcon: some View {
        if let provider = tab.provider {
            provider.iconImage(size: 10)
                .foregroundStyle(provider.tintColor)
        } else {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
        }
    }
}
