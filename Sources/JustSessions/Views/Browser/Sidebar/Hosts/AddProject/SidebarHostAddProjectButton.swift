import SwiftUI

struct SidebarHostAddProjectButton: View {
    let host: SessionHost
    let archivedProjectCount: Int
    let onAddProject: () -> Void
    let onShowArchivedProjects: () -> Void

    var body: some View {
        if archivedProjectCount > 0 {
            Menu {
                Button("Add project…", systemImage: "plus", action: onAddProject)
                Button(
                    "Archived projects (\(archivedProjectCount))\u{2026}", systemImage: "archivebox",
                    action: onShowArchivedProjects)
            } label: {
                plusSymbol
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(ThemePlainButtonStyle(cornerRadius: .small))
            .fixedSize()
            .help(addOrRestoreProjectHelpText)
            .accessibilityLabel(addOrRestoreProjectAccessibilityLabel)
        } else {
            Button(action: onAddProject) { plusSymbol }
                .buttonStyle(ThemePlainButtonStyle(cornerRadius: .small))
                .help(addProjectHelpText)
                .accessibilityLabel(addProjectAccessibilityLabel)
        }
    }

    private var plusSymbol: some View {
        Image(systemName: "plus")
            .font(ThemeFont.glyph(.control, weight: .bold))
            .foregroundStyle(ThemePalette.secondaryText)
            .frame(width: InterfaceScale.points(16), height: InterfaceScale.points(16))
            .contentShape(Rectangle())
    }

    private var addProjectHelpText: LocalizedStringKey {
        host == .thisMac ? "Add a project folder on this Mac" : "Add a project folder on \(host.displayName)"
    }

    private var addProjectAccessibilityLabel: LocalizedStringKey {
        host == .thisMac ? "Add project on this Mac" : "Add project on \(host.displayName)"
    }

    private var addOrRestoreProjectHelpText: LocalizedStringKey {
        host == .thisMac
            ? "Add a project folder or restore an archived project on this Mac"
            : "Add a project folder or restore an archived project on \(host.displayName)"
    }

    private var addOrRestoreProjectAccessibilityLabel: LocalizedStringKey {
        host == .thisMac ? "Add or restore a project on this Mac" : "Add or restore a project on \(host.displayName)"
    }
}
