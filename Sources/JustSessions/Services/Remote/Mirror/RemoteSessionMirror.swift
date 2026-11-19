import Foundation

struct RemoteSessionMirror: Sendable {
    let cacheRoot: URL
    let sourceHomeOverride: String?
    let toolFoldersLookup: @Sendable (_ host: String, _ connectionSharingOptions: [String]) throws -> RemoteToolFolders
    let connectionSharing: @Sendable (_ host: String) -> SSHConnectionSharing?

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
        self.connectionSharing =
            connectionSharing ?? { host in
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

    func kiroV3MirrorDirectory(host: String) -> URL {
        cacheRoot.appendingPathComponent(Self.directoryName(forHost: host)).appendingPathComponent("kiro-v3")
    }

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

    func synchronize(
        host: String,
        provider: ConversationProvider,
        folders: RemoteToolFolders,
        connectionSharingOptions: [String]
    ) throws {
        let destination = mirrorDirectory(host: host, provider: provider)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        if provider == .antigravity {
            try AntigravityRemoteSessionMirror(
                runner: RemoteHostCommandRunner(connectionSharingOptions: connectionSharingOptions, cancelsWithTask: true)
            )
            .synchronize(
                host: host,
                sourceHomeOverride: sourceHomeOverride,
                destination: destination,
                connectionSharingOptions: connectionSharingOptions
            )
            return
        }
        if provider == .opencode {
            try OpenCodeRemoteSessionMirror(
                runner: RemoteHostCommandRunner(connectionSharingOptions: connectionSharingOptions, cancelsWithTask: true)
            )
            .synchronize(
                host: host,
                sourceHomeOverride: sourceHomeOverride,
                destination: destination,
                connectionSharingOptions: connectionSharingOptions
            )
            return
        }
        let source =
            sourceHomeOverride.map { folders.localPath(for: provider, sourceHome: $0) + "/" }
            ?? folders.rsyncSource(host: host, provider: provider)
        try copy(
            host: host, filters: Self.filters(for: provider), from: source, to: destination,
            extraArguments: provider == .opencode ? ["--ignore-times"] : [], connectionSharingOptions: connectionSharingOptions)
        if provider == .kiro {
            let v3Destination = kiroV3MirrorDirectory(host: host)
            try FileManager.default.createDirectory(at: v3Destination, withIntermediateDirectories: true)
            let v3Source =
                sourceHomeOverride.map { RemoteToolFolders.localPath(folders.kiroV3, sourceHome: $0) + "/" }
                ?? RemoteToolFolders.rsyncSource(host: host, path: folders.kiroV3)
            try copy(
                host: host, filters: Self.kiroV3Filters(excludingClassicFolder: (folders.kiro as NSString).lastPathComponent),
                from: v3Source, to: v3Destination, extraArguments: [], connectionSharingOptions: connectionSharingOptions)
        }
    }

    private func copy(
        host: String,
        filters: [String],
        from source: String,
        to destination: URL,
        extraArguments: [String],
        connectionSharingOptions: [String]
    ) throws {
        guard
            let result = Self.runRsync(
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

    static func runRsync(
        for provider: ConversationProvider,
        source: String,
        destination: String,
        connectionSharingOptions: [String]
    ) -> (exitStatus: Int32, output: String)? {
        runRsync(
            filters: filters(for: provider), extraArguments: provider == .opencode ? ["--ignore-times"] : [],
            source: source, destination: destination, connectionSharingOptions: connectionSharingOptions)
    }

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

    static func rsyncRemoteShell(connectionSharingOptions: [String]) -> String {
        (["ssh", RemoteHostCommandRunner.noTerminalOption] + RemoteHostCommandRunner.nonInteractiveSSHOptions + connectionSharingOptions)
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
