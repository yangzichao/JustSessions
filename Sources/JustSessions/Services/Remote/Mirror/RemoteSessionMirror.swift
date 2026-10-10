import Foundation

/// Keeps a local copy of a remote host's session files, so the local adapters and transcript readers work on
/// them unchanged. `rsync` over SSH only transfers what changed since the last copy.
struct RemoteSessionMirror: Sendable {
    let cacheRoot: URL
    /// Replaces `<host>:` as the source, so tests can copy from a local folder that stands in for the remote home.
    let sourceHomeOverride: String?

    init(cacheRoot: URL = RemoteSessionMirror.defaultCacheRoot, sourceHomeOverride: String? = nil) {
        self.cacheRoot = cacheRoot
        self.sourceHomeOverride = sourceHomeOverride
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

    /// Copies the host's session files for each tool.
    func synchronize(host: String) throws {
        for provider in ConversationProvider.allCases {
            try synchronize(host: host, provider: provider)
        }
    }

    func removeMirror(host: String) {
        try? FileManager.default.removeItem(at: cacheRoot.appendingPathComponent(Self.directoryName(forHost: host)))
    }

    func synchronize(host: String, provider: ConversationProvider) throws {
        let destination = mirrorDirectory(host: host, provider: provider)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        if provider == .antigravity {
            try AntigravityRemoteSessionMirror().synchronize(host: host, sourceHomeOverride: sourceHomeOverride, destination: destination)
            return
        }
        if provider == .opencode {
            try OpenCodeRemoteSessionMirror().synchronize(host: host, sourceHomeOverride: sourceHomeOverride, destination: destination)
            return
        }
        let remoteFolder = Self.remoteFolder(for: provider)
        let source = sourceHomeOverride.map { "\($0)/\(remoteFolder)/" } ?? "\(host):\(remoteFolder)/"

        guard let result = Self.runRsync(for: provider, source: source, destination: destination.path + "/", host: sourceHomeOverride == nil ? host : nil)
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
    /// `host` is the SSH host the source is on, whose connection the copy shares, or nil for a local folder.
    static func runRsync(
        for provider: ConversationProvider,
        source: String,
        destination: String,
        host: String?
    ) -> (exitStatus: Int32, output: String)? {
        let remoteShell = rsyncRemoteShell(connectionSharingOptions: host.map(SSHConnectionSharing.options(for:)) ?? [])
        return BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/rsync",
            arguments: rsyncArguments(for: provider, source: source, destination: destination, remoteShell: remoteShell),
            environment: SSHProcessEnvironment.standard,
            includesStandardError: true,
            timeout: 600
        )
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
            ["/*/", "/*/*.jsonl"]
        case .opencode:
            ["/opencode.db"]
        }
    }

    /// Relative to the remote home directory.
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

    /// One path component inside `cacheRoot`. A name of dots alone, or no name, would stand for `cacheRoot`
    /// or its parent, so removing that host's mirror would remove every mirror, or more.
    static func directoryName(forHost host: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_@"))
        let name = String(host.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return name.allSatisfy { $0 == "." } ? "_" + name : name
    }
}
