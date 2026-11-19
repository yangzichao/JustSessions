import Foundation

struct RemoteSessionMirror: Sendable {
    let cacheRoot: URL
    let hostAccess: RemoteMirrorHostAccess
    let toolFoldersLookup: @Sendable (_ host: String, _ connectionSharingOptions: [String]) throws -> RemoteToolFolders

    init(
        cacheRoot: URL = RemoteSessionMirror.defaultCacheRoot,
        hostAccess: RemoteMirrorHostAccess = .ssh,
        toolFoldersLookup: (@Sendable (_ host: String) throws -> RemoteToolFolders)? = nil
    ) {
        self.cacheRoot = cacheRoot
        self.hostAccess = hostAccess
        if let toolFoldersLookup {
            self.toolFoldersLookup = { host, _ in try toolFoldersLookup(host) }
        } else {
            self.toolFoldersLookup = { host, options in
                try RemoteToolFoldersLookup.folders(on: host, runner: hostAccess.commandRunner(options))
            }
        }
    }

    static var defaultCacheRoot: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent(AppIdentity.currentBundleIdentifier).appendingPathComponent("RemoteHosts")
    }

    func mirrorDirectory(host: String, provider: ConversationProvider) -> URL {
        cacheRoot
            .appendingPathComponent(Self.directoryName(forHost: host))
            .appendingPathComponent(Self.mirroredFolderName(for: provider))
    }

    func kiroV3MirrorDirectory(host: String) -> URL {
        cacheRoot.appendingPathComponent(Self.directoryName(forHost: host)).appendingPathComponent("kiro-v3")
    }

    func synchronize(host: String) throws {
        let sharing = hostAccess.connectionSharing(host)
        defer { sharing?.finish() }
        let options = sharing?.options ?? []
        let folders = try lookUpToolFolders(host: host, connectionSharingOptions: options)
        for provider in ConversationProvider.allCases {
            try synchronize(host: host, provider: provider, folders: folders, connectionSharingOptions: options)
        }
    }

    func removeMirror(host: String) {
        try? FileManager.default.removeItem(at: cacheRoot.appendingPathComponent(Self.directoryName(forHost: host)))
    }

    func synchronize(
        host: String,
        provider: ConversationProvider,
        folders: RemoteToolFolders,
        connectionSharingOptions: [String]
    ) throws {
        let destination = mirrorDirectory(host: host, provider: provider)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let runner = hostAccess.commandRunner(connectionSharingOptions)
        let remoteShell = hostAccess.rsyncRemoteShell(connectionSharingOptions)
        if provider == .antigravity {
            try AntigravityRemoteSessionMirror(runner: runner, rsyncRemoteShell: remoteShell)
                .synchronize(host: host, destination: destination)
            return
        }
        if provider == .opencode {
            try OpenCodeRemoteSessionMirror(runner: runner, rsyncRemoteShell: remoteShell)
                .synchronize(host: host, destination: destination)
            return
        }
        try copy(
            host: host,
            arguments: Self.rsyncArguments(
                for: provider,
                source: folders.rsyncSource(host: host, provider: provider),
                destination: destination.path + "/",
                remoteShell: remoteShell
            ),
            into: destination
        )
        if provider == .kiro {
            let v3Destination = kiroV3MirrorDirectory(host: host)
            try FileManager.default.createDirectory(at: v3Destination, withIntermediateDirectories: true)
            try copy(
                host: host,
                arguments: Self.rsyncArguments(
                    filters: Self.kiroV3Filters(excludingClassicFolder: (folders.kiro as NSString).lastPathComponent),
                    ignoresFileDates: false,
                    source: RemoteToolFolders.rsyncSource(host: host, path: folders.kiroV3),
                    destination: v3Destination.path + "/",
                    remoteShell: remoteShell
                ),
                into: v3Destination
            )
        }
    }

    private func copy(host: String, arguments: [String], into destination: URL) throws {
        guard let result = Self.runRsync(arguments: arguments) else { throw RemoteSessionMirrorError.couldNotRun(host: host) }

        switch result.exitStatus {
        case 0:
            return
        case 23 where result.output.contains("No such file or directory"):
            try? FileManager.default.removeItem(at: destination)
        case RemoteHostCommandRunner.connectionFailureExitStatus:
            // rsync passes on the exit status of the `ssh` it runs, and prints what `ssh` printed.
            throw RemoteSessionMirrorError.sshFailed(host: host, problem: SSHConnectionProblem(sshOutput: result.output))
        case _ where result.output.contains("rsync: command not found") || result.output.contains("rsync: not found"):
            throw RemoteSessionMirrorError.rsyncMissingOnHost(host: host)
        default:
            let lastLine = result.output.split(separator: "\n").last.map(String.init) ?? "exit status \(result.exitStatus)"
            throw RemoteSessionMirrorError.rsyncFailed(host: host, output: lastLine)
        }
    }

    static func runRsync(arguments: [String]) -> (exitStatus: Int32, output: String)? {
        BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/rsync",
            arguments: arguments,
            environment: SSHProcessEnvironment.standard,
            includesStandardError: true,
            timeout: 600,
            cancelsWithTask: true
        )
    }

    static func filters(for provider: ConversationProvider) -> [String] {
        includedPatterns(for: provider).map { "--include=\($0)" } + ["--exclude=*"]
    }

    static func kiroV3Filters(excludingClassicFolder classicFolder: String) -> [String] {
        ["--exclude=/\(classicFolder)/"]
            + [
                "/*/", "/*/\(KiroV3Session.idPrefix)*/", "/*/\(KiroV3Session.idPrefix)*/\(KiroV3Session.metadataFileName)",
                "/*/\(KiroV3Session.idPrefix)*/\(KiroV3Session.messagesFileName)",
            ].map { "--include=\($0)" }
            + ["--exclude=*"]
    }

    static func rsyncArguments(
        for provider: ConversationProvider,
        source: String,
        destination: String,
        remoteShell: String
    ) -> [String] {
        rsyncArguments(
            filters: filters(for: provider), ignoresFileDates: provider == .opencode,
            source: source, destination: destination, remoteShell: remoteShell)
    }

    /// No `--prune-empty-dirs`: it drops a project folder whose last session was deleted from the transfer,
    /// and `--delete` then never removes that session from the mirror. OpenCode's snapshot is rebuilt for every
    /// copy, and macOS's `rsync` compares file dates in whole seconds, so a snapshot of the same size made within
    /// the same second would look unchanged; `--ignore-times` compares its contents instead.
    static func rsyncArguments(
        filters: [String],
        ignoresFileDates: Bool,
        source: String,
        destination: String,
        remoteShell: String
    ) -> [String] {
        ["--archive", "--delete", "-e", remoteShell] + (ignoresFileDates ? ["--ignore-times"] : []) + filters
            + [source, destination]
    }

    static func rsyncRemoteShell(connectionSharingOptions: [String]) -> String {
        rsyncRemoteShellCommand(
            ["ssh", RemoteHostCommandRunner.noTerminalOption] + RemoteHostCommandRunner.nonInteractiveSSHOptions
                + connectionSharingOptions)
    }

    /// `rsync -e` splits its command at spaces and keeps what single or double quotes hold together, a doubled quote
    /// standing for one; macOS's openrsync and rsync 3 do the same.
    static func rsyncRemoteShellCommand(_ words: [String]) -> String {
        words.map { word in
            guard word.isEmpty || word.contains(where: { $0 == " " || $0 == "'" || $0 == "\"" }) else { return word }
            return "'" + word.replacingOccurrences(of: "'", with: "''") + "'"
        }
        .joined(separator: " ")
    }

    static func includedPatterns(for provider: ConversationProvider) -> [String] {
        switch provider {
        case .claude:
            ["/projects/", "/projects/*/", "/projects/*/*.jsonl", "/projects/*/sessions-index.json"]
        case .codex:
            ["/session_index.jsonl", "/sessions/", "/sessions/**/", "/sessions/**/rollout-*.jsonl"]
        case .kiro:
            ["/*.json", "/*.jsonl"]
        case .antigravity:
            [
                "/conversation_summaries.db", "/conversation_summaries.db-wal", "/conversation_summaries.db-shm",
                "/conversations/", "/conversations/*.db", "/conversations/*.db-wal", "/conversations/*.db-shm",
            ]
        case .pi:
            ["/*.jsonl", "/*/", "/*/*.jsonl"]
        case .opencode:
            ["/opencode.db"]
        }
    }

    static func remoteFolder(for provider: ConversationProvider) -> String {
        switch provider {
        case .claude: ".claude"
        case .codex: ".codex"
        case .antigravity: ".gemini/antigravity-cli"
        case .kiro: ".kiro/sessions/cli"
        case .opencode: ".local/share/opencode"
        case .pi: ".pi/agent/sessions"
        }
    }

    static func copiesSessionsWithPython3(for provider: ConversationProvider) -> Bool {
        switch provider {
        case .antigravity, .opencode: true
        case .claude, .codex, .kiro, .pi: false
        }
    }

    private static func mirroredFolderName(for provider: ConversationProvider) -> String {
        switch provider {
        case .claude: "claude"
        case .codex: "codex"
        case .antigravity: "antigravity"
        case .kiro: "kiro"
        case .opencode: "opencode"
        case .pi: "pi"
        }
    }

}
