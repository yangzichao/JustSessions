import Foundation

/// Keeps a local copy of a remote host's session files, so the local adapters and transcript readers work on
/// them unchanged. `rsync` over SSH only transfers what changed since the last copy.
struct RemoteSessionMirror: Sendable {
    let cacheRoot: URL
    /// Replaces `<host>:` as the source, so tests can copy from a local folder that stands in for the remote home.
    let sourceHomeOverride: String?
    /// Finds where the host keeps each tool's files; see `RemoteToolFoldersLookup`.
    let toolFoldersLookup: @Sendable (_ host: String, _ connectionSharingOptions: [String]) throws -> RemoteToolFolders
    /// Makes the private connection scope shared by one refresh's commands and copies.
    let connectionSharing: @Sendable (_ host: String) -> SSHConnectionSharing?

    /// Without a `toolFoldersLookup`, a host stood in for by `sourceHomeOverride` keeps the standard folders.
    init(
        cacheRoot: URL = RemoteSessionMirror.defaultCacheRoot,
        sourceHomeOverride: String? = nil,
        toolFoldersLookup: (@Sendable (_ host: String) throws -> RemoteToolFolders)? = nil,
        connectionSharing: (@Sendable (_ host: String) -> SSHConnectionSharing?)? = nil
    ) {
        self.cacheRoot = cacheRoot
        self.sourceHomeOverride = sourceHomeOverride
        if let toolFoldersLookup {
            self.toolFoldersLookup = { host, _ in try toolFoldersLookup(host) }
        } else if sourceHomeOverride == nil {
            self.toolFoldersLookup = { host, options in
                try RemoteToolFoldersLookup.folders(
                    on: host,
                    runner: RemoteHostCommandRunner(connectionSharingOptions: options, cancelsWithTask: true)
                )
            }
        } else {
            self.toolFoldersLookup = { _, _ in .standard }
        }
        self.connectionSharing = connectionSharing ?? { host in
            sourceHomeOverride == nil ? SSHConnectionSharing.startRefresh(to: host) : nil
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

    /// Where Kiro V3's sessions are copied, beside V2's `mirrorDirectory(host:provider: .kiro)`; see `KiroV3Session`.
    func kiroV3MirrorDirectory(host: String) -> URL {
        cacheRoot.appendingPathComponent(Self.directoryName(forHost: host)).appendingPathComponent("kiro-v3")
    }

    /// Copies the host's session files for each tool through one app-owned connection scope.
    func synchronize(host: String) throws {
        let sharing = connectionSharing(host)
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

    /// `folders` comes from `lookUpToolFolders(host:)`, once for all of the host's tools.
    func synchronize(host: String, provider: ConversationProvider, folders: RemoteToolFolders) throws {
        try synchronize(host: host, provider: provider, folders: folders, connectionSharingOptions: [])
    }

    func synchronize(
        host: String,
        provider: ConversationProvider,
        folders: RemoteToolFolders,
        connectionSharingOptions: [String]
    ) throws {
        let destination = mirrorDirectory(host: host, provider: provider)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        if provider == .antigravity {
            try AntigravityRemoteSessionMirror(runner: RemoteHostCommandRunner(connectionSharingOptions: connectionSharingOptions, cancelsWithTask: true))
                .synchronize(
                    host: host,
                    sourceHomeOverride: sourceHomeOverride,
                    destination: destination,
                    connectionSharingOptions: connectionSharingOptions
                )
            return
        }
        if provider == .opencode {
            try OpenCodeRemoteSessionMirror(runner: RemoteHostCommandRunner(connectionSharingOptions: connectionSharingOptions, cancelsWithTask: true))
                .synchronize(
                    host: host,
                    sourceHomeOverride: sourceHomeOverride,
                    destination: destination,
                    connectionSharingOptions: connectionSharingOptions
                )
            return
        }
        let source = sourceHomeOverride.map { folders.localPath(for: provider, sourceHome: $0) + "/" }
            ?? folders.rsyncSource(host: host, provider: provider)
        try copy(host: host, filters: Self.filters(for: provider), from: source, to: destination,
                 extraArguments: provider == .opencode ? ["--ignore-times"] : [], connectionSharingOptions: connectionSharingOptions)
        if provider == .kiro {
            let v3Destination = kiroV3MirrorDirectory(host: host)
            try FileManager.default.createDirectory(at: v3Destination, withIntermediateDirectories: true)
            let v3Source = sourceHomeOverride.map { RemoteToolFolders.localPath(folders.kiroV3, sourceHome: $0) + "/" }
                ?? RemoteToolFolders.rsyncSource(host: host, path: folders.kiroV3)
            try copy(host: host, filters: Self.kiroV3Filters(excludingClassicFolder: (folders.kiro as NSString).lastPathComponent),
                     from: v3Source, to: v3Destination, extraArguments: [], connectionSharingOptions: connectionSharingOptions)
        }
    }

    /// One `rsync` of `source` into `destination`; a source the host doesn't have empties the copy.
    private func copy(
        host: String,
        filters: [String],
        from source: String,
        to destination: URL,
        extraArguments: [String],
        connectionSharingOptions: [String]
    ) throws {
        guard let result = Self.runRsync(
            filters: filters,
            extraArguments: extraArguments,
            source: source,
            destination: destination.path + "/",
            connectionSharingOptions: sourceHomeOverride == nil ? connectionSharingOptions : []
        )
        else { throw RemoteSessionMirrorError.couldNotRun(host: host) }

        switch result.exitStatus {
        case 0:
            return
        case 23 where result.output.contains("No such file or directory"):
            // The tool was never used on this host.
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

    /// Copies one tool's files, with `ssh` running in the login shell's environment like the app's other connections.
    static func runRsync(
        for provider: ConversationProvider,
        source: String,
        destination: String,
        connectionSharingOptions: [String]
    ) -> (exitStatus: Int32, output: String)? {
        runRsync(filters: filters(for: provider), extraArguments: provider == .opencode ? ["--ignore-times"] : [],
                 source: source, destination: destination, connectionSharingOptions: connectionSharingOptions)
    }

    /// Copies `source` with `filters`, as `rsyncArguments(for:source:destination:remoteShell:)` lays a tool's out.
    static func runRsync(
        filters: [String],
        extraArguments: [String],
        source: String,
        destination: String,
        connectionSharingOptions: [String]
    ) -> (exitStatus: Int32, output: String)? {
        let remoteShell = rsyncRemoteShell(connectionSharingOptions: connectionSharingOptions)
        return BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/rsync",
            arguments: ["--archive", "--delete", "-e", remoteShell] + extraArguments + filters + [source, destination],
            environment: SSHProcessEnvironment.standard,
            includesStandardError: true,
            timeout: 600,
            cancelsWithTask: true
        )
    }

    /// The tool's `includedPatterns`, then everything else left out.
    static func filters(for provider: ConversationProvider) -> [String] {
        includedPatterns(for: provider).map { "--include=\($0)" } + ["--exclude=*"]
    }

    /// Each V3 session's `session.json` and `messages.jsonl`, in its workspace folder. V2's own folder, copied apart,
    /// and a session's `sub-executions`, `snapshots`, and cursors stay on the host.
    static func kiroV3Filters(excludingClassicFolder classicFolder: String) -> [String] {
        ["--exclude=/\(classicFolder)/"]
            + ["/*/", "/*/\(KiroV3Session.idPrefix)*/", "/*/\(KiroV3Session.idPrefix)*/\(KiroV3Session.metadataFileName)",
               "/*/\(KiroV3Session.idPrefix)*/\(KiroV3Session.messagesFileName)"].map { "--include=\($0)" }
            + ["--exclude=*"]
    }

    /// No `--prune-empty-dirs`: it drops a project folder whose last session was deleted from the transfer,
    /// and `--delete` then never removes that session from the mirror. OpenCode's snapshot is rebuilt for every
    /// copy, and macOS's `rsync` compares file dates in whole seconds, so a snapshot of the same size made within
    /// the same second would look unchanged; `--ignore-times` compares its contents instead.
    static func rsyncArguments(
        for provider: ConversationProvider,
        source: String,
        destination: String,
        remoteShell: String
    ) -> [String] {
        [
            "--archive", "--delete",
            "-e", remoteShell,
        ]
            + (provider == .opencode ? ["--ignore-times"] : [])
            + includedPatterns(for: provider).map { "--include=\($0)" }
            + ["--exclude=*", source, destination]
    }

    /// The `ssh` command `rsync` connects with; none of the options has a space, the socket folder's path included,
    /// so joining them needs no quoting.
    static func rsyncRemoteShell(connectionSharingOptions: [String]) -> String {
        (["ssh", RemoteHostCommandRunner.noTerminalOption] + RemoteHostCommandRunner.nonInteractiveSSHOptions + connectionSharingOptions)
            .joined(separator: " ")
    }

    /// Only the files the adapters read; Claude Code's subagent transcripts and caches stay on the host, and so do
    /// the subagent runs, forks, and artifacts Pi extensions keep in folders inside a Pi project folder. OpenCode's
    /// database is copied from a snapshot that holds only its sessions.
    static func includedPatterns(for provider: ConversationProvider) -> [String] {
        switch provider {
        case .claude:
            ["/projects/", "/projects/*/", "/projects/*/*.jsonl", "/projects/*/sessions-index.json"]
        case .codex:
            ["/session_index.jsonl", "/sessions/", "/sessions/**/", "/sessions/**/rollout-*.jsonl"]
        case .kiro:
            ["/*.json", "/*.jsonl"]
        case .antigravity:
            ["/conversation_summaries.db", "/conversation_summaries.db-wal", "/conversation_summaries.db-shm",
             "/conversations/", "/conversations/*.db", "/conversations/*.db-wal", "/conversations/*.db-shm"]
        case .pi:
            ["/*.jsonl", "/*/", "/*/*.jsonl"]
        case .opencode:
            ["/opencode.db"]
        }
    }

    /// Relative to the remote home directory, where the tool keeps its files unless the host's environment says
    /// otherwise; see `RemoteToolFolders`.
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
