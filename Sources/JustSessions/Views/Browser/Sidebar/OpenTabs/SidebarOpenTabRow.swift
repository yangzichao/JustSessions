import SwiftUI

/// An open tab: its tool's icon, the tab's title, and its CLI's status, highlighted while the tab is selected.
struct SidebarOpenTabRow: View {
    @ObservedObject var tab: TerminalSession
    let projectDisplayName: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    static let height: CGFloat = 28

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                toolIcon
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 14)
                Text(tab.displayTitle)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
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
        .buttonStyle(.plain)
        .help(Text("Show \(tab.displayTitle)") + Text(verbatim: "\n" + projectDisplayName))
        .accessibilityLabel(Text(verbatim: "\(tab.displayTitle), \(projectDisplayName)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            if tab.isPlainTerminal {
                Button("Close terminal…", systemImage: "xmark", role: .destructive, action: onClose)
            } else {
                Button("End session…", systemImage: "xmark", role: .destructive, action: onClose)
            }
        }
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
