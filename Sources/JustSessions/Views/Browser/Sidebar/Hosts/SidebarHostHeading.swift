import SwiftUI

/// A host's heading above its projects: its name, how its last refresh went, and its project count, which gives way
/// to a + for adding a project there while the pointer is over it. New sessions start from a project's own +, so the
/// heading manages the host's projects instead. Right-click to add a project, restore archived projects, refresh the
/// host, or remove an SSH host.
/// The heading is shown even while this Mac is the only host, so the sidebar always reads by host; in that case it
/// leaves refresh progress to the sidebar header.
struct SidebarHostHeading: View {
    let host: SessionHost
    let isOnlyHost: Bool
    let refreshStatus: HostRefreshStatus?
    let projectCount: Int
    let onAddProject: () -> Void
    let onRefresh: () -> Void
    /// While sessions are being deleted, refreshing waits, as the sidebar header's button does.
    let isRefreshDisabled: Bool
    let archivedProjectCount: Int
    let onShowArchivedProjects: () -> Void
    /// Nil for this Mac, which is always listed.
    let onRemove: (() -> Void)?

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
            refreshStatusIndicator
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
            Button("Add project…", systemImage: "plus", action: onAddProject)
            if archivedProjectCount > 0 {
                Button("Archived projects (\(archivedProjectCount))\u{2026}", systemImage: "archivebox",
                       action: onShowArchivedProjects)
            }
            Divider()
            Button("Refresh", systemImage: "arrow.clockwise", action: onRefresh)
                .disabled(refreshStatus == .refreshing || isRefreshDisabled)
            if let onRemove {
                Divider()
                Button("Remove host", systemImage: "minus.circle", role: .destructive, action: onRemove)
            }
        }
    }

    @ViewBuilder
    private var refreshStatusIndicator: some View {
        switch refreshStatus {
        case .refreshing?:
            if !isOnlyHost {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 12, height: 12)
                    .accessibilityLabel("Refreshing \(host.displayName)")
            }
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
            Button(action: onAddProject) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .help(addProjectHelpText)
            .accessibilityLabel(addProjectAccessibilityLabel)
        }
    }

    private var addProjectHelpText: LocalizedStringKey {
        host == .thisMac ? "Add a project folder on this Mac" : "Add a project folder on \(host.displayName)"
    }

    private var addProjectAccessibilityLabel: LocalizedStringKey {
        host == .thisMac ? "Add project on this Mac" : "Add project on \(host.displayName)"
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
