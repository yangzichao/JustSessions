import SwiftUI

struct SidebarHostHeading: View {
    let host: SessionHost
    let refreshStatus: HostRefreshStatus?
    let copyStep: RemoteSessionCopyStep?
    let projectCount: Int
    let onAddProject: () -> Void
    let onRefresh: () -> Void
    let isRefreshDisabled: Bool
    let archivedProjectCount: Int
    let onShowArchivedProjects: () -> Void
    let sshHostActions: SidebarSSHHostActions?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: host.symbolName)
                .font(ThemeFont.glyph(.control, weight: .medium))
                .foregroundStyle(ThemePalette.tertiaryText)
                .frame(width: InterfaceScale.points(14))
            Group {
                if host == .thisMac { Text("This Mac") } else { Text(verbatim: host.displayName) }
            }
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(ThemePalette.secondaryText)
            .lineLimit(1)
            .truncationMode(.middle)
            if !isDisconnected { warningsAndButtons }
            Spacer(minLength: 6)
            refreshStatusOrMoreActions
            SidebarHostRefreshButton(
                host: host,
                refreshStatus: refreshStatus,
                isDisabled: isRefreshDisabled,
                connectsFirst: isDisconnected,
                action: onRefresh
            )
            projectCountOrAddProjectButton
        }
        .font(ThemeFont.caption.weight(.semibold))
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(height: InterfaceScale.points(20))
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

    private var isDisconnected: Bool {
        sshHostActions?.login == .disconnected
    }

    @ViewBuilder
    private var warningsAndButtons: some View {
        Group {
            if let sshHostActions,
                sshHostActions.login == .loggingIn
                    || sshHostActions.login == .notLoggedIn(needsLogIn: true)
            {
                SidebarHostConnectButton(
                    host: host,
                    isLoggingIn: sshHostActions.login == .loggingIn,
                    failureMessage: failureMessage,
                    action: sshHostActions.onConnect
                )
            } else if let sshHostActions, sshHostActions.signIn == .due || sshHostActions.signIn == .signingIn {
                SidebarHostSignInButton(
                    host: host,
                    isSigningIn: sshHostActions.signIn == .signingIn,
                    action: sshHostActions.onSignIn
                )
            } else if let failureMessage {
                SidebarHostRefreshFailureWarning(
                    host: host,
                    failureMessage: failureMessage,
                    onCheckHost: sshHostActions?.onCheckHost
                )
            }
            if let shellStartupCheck = sshHostActions?.shellStartupCheck, shellStartupCheck.outcome == .blocked {
                SidebarHostShellStartupWarning(host: host, stoppedAt: shellStartupCheck.stoppedAt)
            } else if let sshHostActions, failureMessage == nil, let hostCheckProblem = sshHostActions.hostCheckProblem,
                sshHostActions.login != .loggingIn, sshHostActions.login != .notLoggedIn(needsLogIn: true)
            {
                SidebarHostCheckProblemWarning(
                    host: host,
                    problemMessage: hostCheckProblem,
                    onShowHostCheck: sshHostActions.onShowHostCheck
                )
            }
        }
    }

    private var failureMessage: String? {
        guard case .failed(let message)? = refreshStatus else { return nil }
        return message
    }

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
        if isDisconnected {
            SidebarHostDisconnectedLabel(host: host)
        } else {
            refreshStatusIndicatorWhileConnected
        }
    }

    @ViewBuilder
    private var refreshStatusIndicatorWhileConnected: some View {
        switch refreshStatus {
        case .refreshing?:
            if let copyStep {
                Text(verbatim: "\(copyStep.number)/\(copyStep.count)")
                    .font(ThemeFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(ThemePalette.tertiaryText)
                    .fixedSize()
                    .accessibilityLabel(
                        Text(
                            "Copying \(copyStep.provider.rawValue) sessions (\(copyStep.number) of \(copyStep.count))…"
                        ))
            }
        case .failed?:
            EmptyView()
        case .refreshed(let syncDate)?:
            if host != .thisMac {
                TimelineView(.everyMinute) { context in
                    Text(HostSyncAgeFormatter.string(forSyncedAt: syncDate, relativeTo: context.date))
                        .font(ThemeFont.caption)
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
        let summary =
            host == .thisMac
            ? "Sessions on this Mac"
            : "Sessions on \(host.displayName), copied over SSH"
        if isDisconnected {
            guard case .refreshed(let date)? = refreshStatus else { return "\(summary). Disconnected." }
            return "\(summary). Disconnected; last refreshed at \(date.formatted(date: .omitted, time: .shortened))."
        }
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
