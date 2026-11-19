import Foundation

extension ConversationStore {
    func openPlainTerminal(in location: ProjectLocation) {
        connectIfDisconnected(location.host)
        do {
            openTerminal(try makePlainTerminal(in: location))
        } catch {
            showError(error.localizedDescription)
        }
    }

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
