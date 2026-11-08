import Foundation

/// A plain terminal: your login shell in a project folder, on the project's host. It runs no CLI and is no session,
/// so the app never lists it, links it to a session, or watches what it does. Where the host has tmux, the shell runs
/// in a tmux session of the tab's own, so it outlives a quit, an update, or a dropped connection, and the tab attaches
/// to it again; closing the tab ends it (see `ConversationStore+PlainTerminalTmux`). Without tmux it ends with its tab.
extension ConversationStore {
    func openPlainTerminal(in location: ProjectLocation) {
        connectIfDisconnected(location.host)
        do {
            openTerminal(try makePlainTerminal(in: location))
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// From the New Session sheet, which shows the error. The typed folder is looked up on its host first, so a
    /// missing folder is reported before a tab opens, or created when `creatingMissingFolder` is set.
    func openPlainTerminal(
        host: SessionHost,
        folder: String,
        creatingMissingFolder: Bool = false,
        resolver: RemoteFolderResolver = RemoteFolderResolver()
    ) async throws {
        let location = try await projectLocation(
            of: folder,
            on: host,
            creatingMissingFolder: creatingMissingFolder,
            resolver: resolver
        )
        openTerminal(try makePlainTerminal(in: location))
    }

    /// A plain terminal tab in the folder, not opened yet. `tmuxSessionName` is the tmux session a reopened tab's shell
    /// ran in, which it attaches to while that shell still runs; a new tab gets a name of its own. It opens with
    /// `engine`, or else the engine chosen now.
    func makePlainTerminal(
        in location: ProjectLocation,
        tmuxSessionName: String? = nil,
        startsOnceShown: Bool = false,
        engine: TerminalEngine? = nil
    ) throws -> TerminalSession {
        let (command, projectPath, runningTmuxSessionName) = try plainTerminalCommand(
            in: location,
            tmuxSessionName: tmuxSessionName ?? TmuxSessionName.forNewPlainTerminal()
        )
        return TerminalSession(
            engine: engine ?? terminalEngineStore.engine,
            conversation: nil,
            provider: nil,
            projectPath: projectPath,
            action: nil,
            displayTitle: "Terminal · \(projectDisplayName(forProjectPath: location.key))",
            command: command,
            host: location.host,
            tmuxSessionName: runningTmuxSessionName,
            startsOnceShown: startsOnceShown,
            tmuxHistory: runningTmuxSessionName.flatMap { plainTerminalTmuxHistory(sessionName: $0, on: location.host) }
        )
    }

    /// Also returns the folder as the tab records it, and the tmux session's name when the shell runs in tmux. An SSH
    /// tab names one even on a host without tmux, where its shell runs directly, as a CLI tab does.
    private func plainTerminalCommand(
        in location: ProjectLocation,
        tmuxSessionName: String
    ) throws -> (command: NativeCLICommand, projectPath: String, tmuxSessionName: String?) {
        switch location.host {
        case .thisMac:
            let expandedPath = (location.path as NSString).expandingTildeInPath
            let standardizedPath = URL(fileURLWithPath: expandedPath).standardizedFileURL.path
            let shell = try commandResolver.resolvePlainTerminal(projectPath: standardizedPath)
            let (command, runningTmuxSessionName) = thisMacTabCommand(
                running: shell,
                tmuxSessionName: tmuxSessionName,
                historyLimit: PlainTerminalTmuxHistoryLimit.lineCount
            )
            return (command, standardizedPath, runningTmuxSessionName)
        case .ssh(let destination):
            let command = RemoteCLICommandBuilder().plainTerminalCommand(
                host: destination,
                projectPath: location.path,
                tmuxSessionName: tmuxSessionName,
                usesHostTmuxPrefix: usesTmuxPrefix(on: location.host)
            )
            return (command, location.path, tmuxSessionName)
        }
    }
}
