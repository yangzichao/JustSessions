import Foundation

/// A plain terminal: your login shell in a project folder, on the project's host. It runs no CLI and is no session,
/// so the app never lists it, links it to a session, or watches what it does. It runs outside tmux and ends with its tab.
extension ConversationStore {
    func openPlainTerminal(in location: ProjectLocation) {
        do {
            openTerminal(try makePlainTerminal(in: location))
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// From the New Session sheet, which shows the error. A folder typed for an SSH host is looked up there first, so a
    /// missing folder is reported before a tab opens.
    func openPlainTerminal(
        host: SessionHost,
        folder: String,
        resolver: RemoteFolderResolver = RemoteFolderResolver()
    ) async throws {
        openTerminal(try makePlainTerminal(in: try await projectLocation(of: folder, on: host, resolver: resolver)))
    }

    /// A plain terminal tab in the folder, not opened yet.
    func makePlainTerminal(in location: ProjectLocation, startsOnceShown: Bool = false) throws -> TerminalSession {
        let (command, projectPath) = try plainTerminalCommand(in: location)
        return TerminalSession(
            conversation: nil,
            provider: nil,
            projectPath: projectPath,
            action: nil,
            displayTitle: "Terminal · \(projectDisplayName(forProjectPath: location.key))",
            command: command,
            host: location.host,
            startsOnceShown: startsOnceShown
        )
    }

    /// Also returns the folder as the tab records it.
    private func plainTerminalCommand(in location: ProjectLocation) throws -> (command: NativeCLICommand, projectPath: String) {
        switch location.host {
        case .thisMac:
            let expandedPath = (location.path as NSString).expandingTildeInPath
            let standardizedPath = URL(fileURLWithPath: expandedPath).standardizedFileURL.path
            return (try commandResolver.resolvePlainTerminal(projectPath: standardizedPath), standardizedPath)
        case .ssh(let destination):
            return (RemoteCLICommandBuilder().plainTerminalCommand(host: destination, projectPath: location.path), location.path)
        }
    }
}
