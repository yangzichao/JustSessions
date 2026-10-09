import SwiftUI

/// A host's heading above its projects: its name, how its last refresh went, and its project count. A failed refresh
/// shows a warning after the name; see `SidebarHostRefreshFailureWarning`. So does an SSH host whose shell startup keeps
/// CLIs from starting; see `SidebarHostShellStartupWarning`. While the pointer is over the heading, the
/// count gives way to a +, and an SSH host's refresh status to a ⋯. The + adds a project there, or
/// restores an archived one; the ⋯ holds the host's own settings, and a right-click opens all the heading's actions.
/// New sessions start from a project's own +, so the heading manages the host's projects instead. Its refresh button
/// refreshes this host alone, and shows its progress. While an SSH host's refresh copies its sessions, the refresh status
/// says how far it is through the tools, and the tooltip which tool it is copying.
struct SidebarHostHeading: View {
    let host: SessionHost
    let refreshStatus: HostRefreshStatus?
    /// Nil unless an SSH host's refresh is copying its sessions.
    let copyStep: RemoteSessionCopyStep?
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
                .foregroundStyle(ThemePalette.tertiaryText)
                .frame(width: 14)
            Group {
                if host == .thisMac { Text("This Mac") }
                else { Text(verbatim: host.displayName) }
            }
            .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(ThemePalette.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            if case .failed(let failureMessage)? = refreshStatus {
                SidebarHostRefreshFailureWarning(host: host, failureMessage: failureMessage)
            }
            if let shellStartupCheck = sshHostActions?.shellStartupCheck, shellStartupCheck.outcome == .blocked {
                SidebarHostShellStartupWarning(host: host, stoppedAt: shellStartupCheck.stoppedAt)
            }
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
            if let copyStep {
                Text(verbatim: "\(copyStep.number)/\(copyStep.count)")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(ThemePalette.tertiaryText)
                    .fixedSize()
                    .accessibilityLabel(Text(
                        "Copying \(copyStep.provider.rawValue) sessions (\(copyStep.number) of \(copyStep.count))…"
                    ))
            }
        case .failed?:
            EmptyView()
        case .refreshed(let syncDate)?:
            // This Mac's files are read in place; only an SSH host's copy can be behind.
            if host != .thisMac {
                TimelineView(.everyMinute) { context in
                    Text(HostSyncAgeFormatter.string(forSyncedAt: syncDate, relativeTo: context.date))
                        .font(.system(size: 10))
                        .foregroundStyle(ThemePalette.tertiaryText)
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
                .foregroundStyle(ThemePalette.tertiaryText)
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
        case .refreshing?:
            guard let copyStep else { return "\(summary). Refreshing…" }
            return "\(summary). Copying \(copyStep.provider.rawValue) sessions (\(copyStep.number) of \(copyStep.count))…"
        case .failed(let message)?: return "\(summary). \(message)"
        case .refreshed(let date)?: return "\(summary). Refreshed at \(date.formatted(date: .omitted, time: .shortened))."
        case nil: return summary
        }
    }
}
