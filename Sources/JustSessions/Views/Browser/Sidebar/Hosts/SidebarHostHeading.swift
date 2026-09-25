import SwiftUI

/// A host's heading above its projects: its name, how its last refresh went, and its project count, which gives way
/// to a + for a new session there while the pointer is over it. Right-click to refresh the host or remove an SSH host.
/// While this Mac is the only host, the heading reads PROJECTS and leaves refresh progress to the sidebar header.
struct SidebarHostHeading: View {
    let host: SessionHost
    let isOnlyHost: Bool
    let refreshStatus: HostRefreshStatus?
    let projectCount: Int
    let onNewSession: () -> Void
    let onRefresh: () -> Void
    /// Nil for this Mac, which is always listed.
    let onRemove: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            if !isOnlyHost {
                // One width for every host's symbol keeps the host names lined up.
                Image(systemName: host.symbolName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
            }
            Text(isOnlyHost ? "PROJECTS" : host.displayName.uppercased())
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            refreshStatusIndicator
            projectCountOrNewSessionButton
        }
        .font(.system(size: 10, weight: .semibold))
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(height: 20)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(helpText)
        .contextMenu {
            Button("New session on \(host.displayName)…", systemImage: "plus", action: onNewSession)
            Button("Refresh", systemImage: "arrow.clockwise", action: onRefresh)
                .disabled(refreshStatus == .refreshing)
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

    private var projectCountOrNewSessionButton: some View {
        ZStack(alignment: .trailing) {
            Text(projectCount.formatted())
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .opacity(isHovered ? 0 : 1)
            Button(action: onNewSession) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .help("Start a new session on \(host.displayName)")
            .accessibilityLabel("New session on \(host.displayName)")
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
