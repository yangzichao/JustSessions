import Foundation

extension TerminalSession {
    var waitingRemoteNewSessionTab: WaitingRemoteNewSessionTab {
        WaitingRemoteNewSessionTab(
            terminalID: id,
            host: host.sshDestination ?? "",
            provider: provider,
            projectPath: projectPath,
            launchedAt: launchedAt,
            sessionIDsKnownAtLaunch: sessionIDsKnownAtLaunch
        )
    }
}
