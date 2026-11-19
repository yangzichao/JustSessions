import Foundation

extension NativeCLICommandResolver {
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

    func beginThisMacTmuxProbeGeneration() -> Int {
        tmuxSelection.beginProbeGeneration()
    }

    func probeThisMacTmuxServer() -> ThisMacTmuxServer? {
        tmuxSelection.probe(from: availableTmuxServers())
    }

    @discardableResult
    func commitThisMacTmuxServer(_ server: ThisMacTmuxServer?, generation: Int) -> ThisMacTmuxServer? {
        tmuxSelection.commit(server, generation: generation)
    }

    func refreshThisMacTmuxServer() -> ThisMacTmuxServer? {
        tmuxSelection.select(from: availableTmuxServers())
    }

    func thisMacTmuxServer() -> ThisMacTmuxServer? {
        installedTmuxServer().flatMap { $0.isKnownToHaveSupportedVersion ? $0 : nil }
    }
}
