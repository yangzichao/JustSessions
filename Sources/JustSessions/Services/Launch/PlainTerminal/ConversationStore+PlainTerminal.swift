import Foundation

/// A plain terminal: your login shell in a project folder, on the project's host. It runs no CLI and is no session,
/// so the app never lists it, links it to a session, or watches what it does. It runs outside tmux and ends with its tab.
extension ConversationStore {
    func openPlainTerminal(in location: ProjectLocation) {
        do {
            let (command, projectPath) = try plainTerminalCommand(in: location)
            let session = TerminalSession(
                conversation: nil,
                provider: nil,
                projectPath: projectPath,
                action: nil,
                displayTitle: "Terminal · \(projectDisplayName(forProjectPath: location.key))",
                command: command,
                host: location.host
            )
            openTerminal(session)
        } catch {
            showError(error.localizedDescription)
        }
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
