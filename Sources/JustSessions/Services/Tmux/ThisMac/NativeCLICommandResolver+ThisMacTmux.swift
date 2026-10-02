import Foundation

extension NativeCLICommandResolver {
    /// The selected tmux, or the bundled-first candidate before the first background refresh.
    func installedTmuxServer() -> ThisMacTmuxServer? {
        tmuxSelection.server ?? availableTmuxServers().first
    }

    func availableTmuxServers() -> [ThisMacTmuxServer] {
        var servers: [ThisMacTmuxServer] = []
        if let bundled = bundledTmuxRuntime?.server(environment: inheritedEnvironment, fileManager: fileManager) {
            servers.append(bundled)
        }
        if let installedPath = executablePath(named: "tmux"), !servers.contains(where: { $0.executablePath == installedPath }) {
            servers.append(ThisMacTmuxServer(executablePath: installedPath, environment: inheritedEnvironment))
        }
        return servers
    }

    /// Checks versions and existing servers off the main thread, preserving previously running work.
    func refreshThisMacTmuxServer() -> ThisMacTmuxServer? {
        tmuxSelection.select(from: availableTmuxServers())
    }

    /// The tmux new tabs run their CLI in: installed and known to be new enough. A refresh of this Mac checks the
    /// version the first time, so until then tabs run the CLI directly.
    func thisMacTmuxServer() -> ThisMacTmuxServer? {
        installedTmuxServer().flatMap { $0.isKnownToHaveSupportedVersion ? $0 : nil }
    }
}
