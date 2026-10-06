import SwiftUI

/// A host's heading above its projects: its name, how its last refresh went, and its project count. While the pointer
/// is over it, the count gives way to a +, and an SSH host's refresh status to a ⋯. The + adds a project there, or
/// restores an archived one; the ⋯ holds the host's own settings, and a right-click opens all the heading's actions.
/// New sessions start from a project's own +, so the heading manages the host's projects instead. Its refresh button
/// refreshes this host alone, and shows its progress.
struct SidebarHostHeading: View {
    let host: SessionHost
    let refreshStatus: HostRefreshStatus?
    let projectCount: Int
    let onAddProject: () -> Void
    let onRefresh: () -> Void
    /// While sessions are being deleted, manual refresh is disabled.
    let isRefreshDisabled: Bool
    let archivedProjectCount: Int
    let onShowArchivedProjects: () -> Void
    /// Nil for this Mac; see `SidebarHostMenuItems`.
    let sshHostActions: SidebarSSHHostActions?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // One width for every host's symbol keeps the host names lined up.
            Image(systemName: host.symbolName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 14)
            Group {
                if host == .thisMac { Text("This Mac") }
                else { Text(verbatim: host.displayName) }
            }
            .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            refreshStatusOrMoreActions
            SidebarHostRefreshButton(
                host: host,
                refreshStatus: refreshStatus,
                isDisabled: isRefreshDisabled,
                action: onRefresh
            )
            projectCountOrAddProjectButton
        }
        .font(.system(size: 10, weight: .semibold))
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(height: 20)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(helpText)
        .contextMenu {
            SidebarHostMenuItems(
                refreshStatus: refreshStatus,
                isRefreshDisabled: isRefreshDisabled,
                archivedProjectCount: archivedProjectCount,
                onAddProject: onAddProject,
                onShowArchivedProjects: onShowArchivedProjects,
                onRefresh: onRefresh,
                sshHostActions: sshHostActions
            )
        }
    }

    /// The ⋯ takes the refresh status's place rather than room of its own, which the host's name would lose. The
    /// heading's tooltip still says when the host was refreshed, or why it could not be.
    private var refreshStatusOrMoreActions: some View {
        ZStack(alignment: .trailing) {
            refreshStatusIndicator
                .opacity(isHovered && sshHostActions != nil ? 0 : 1)
            if let sshHostActions {
                SidebarSSHHostMoreActionsMenu(host: host, actions: sshHostActions)
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(isHovered)
            }
        }
    }

    @ViewBuilder
    private var refreshStatusIndicator: some View {
        switch refreshStatus {
        case .refreshing?:
            EmptyView()
        case .failed(let message)?:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ThemePalette.warning)
                .help(message)
                .accessibilityLabel("\(host.displayName) could not be refreshed: \(message)")
        case .refreshed(let syncDate)?:
            // This Mac's files are read in place; only an SSH host's copy can be behind.
            if host != .thisMac {
                TimelineView(.everyMinute) { context in
                    Text(HostSyncAgeFormatter.string(forSyncedAt: syncDate, relativeTo: context.date))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }
            }
        case nil:
            EmptyView()
        }
    }

    private var projectCountOrAddProjectButton: some View {
        ZStack(alignment: .trailing) {
            Text(projectCount.formatted())
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .opacity(isHovered ? 0 : 1)
            SidebarHostAddProjectButton(
                host: host,
                archivedProjectCount: archivedProjectCount,
                onAddProject: onAddProject,
                onShowArchivedProjects: onShowArchivedProjects
            )
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
        }
    }

    private var helpText: String {
        let summary = host == .thisMac
            ? "Sessions on this Mac"
            : "Sessions on \(host.displayName), copied over SSH"
        switch refreshStatus {
        case .refreshing?: return "\(summary). Refreshing…"
        case .failed(let message)?: return "\(summary). \(message)"
        case .refreshed(let date)?: return "\(summary). Refreshed at \(date.formatted(date: .omitted, time: .shortened))."
        case nil: return summary
        }
    }
}
