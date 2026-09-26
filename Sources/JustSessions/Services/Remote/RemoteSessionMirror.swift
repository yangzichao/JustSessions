import Foundation

enum RemoteSessionMirrorError: LocalizedError {
    case couldNotRun(host: String)
    case sshFailed(host: String)
    case rsyncMissingOnHost(host: String)
    case rsyncFailed(host: String, output: String)

    var errorDescription: String? {
        switch self {
        case .couldNotRun(let host):
            "Copying sessions from \(host) did not start or took longer than 10 minutes."
        case .sshFailed(let host):
            "Could not connect to \(host). Check that `ssh \(host)` works in Terminal without a password prompt "
                + "(use an SSH key or agent)."
        case .rsyncMissingOnHost(let host):
            "rsync is not installed on \(host). Install it there, then refresh."
        case .rsyncFailed(let host, let output):
            "Copying sessions from \(host) failed: \(output)"
        }
    }
}

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

    /// Copies the host's session files for each tool that runs on remote hosts.
    func synchronize(host: String) throws {
        for provider in ConversationProvider.allCases where provider.supportsRemoteHosts {
            try synchronize(host: host, provider: provider)
        }
    }

    func removeMirror(host: String) {
        try? FileManager.default.removeItem(at: cacheRoot.appendingPathComponent(Self.directoryName(forHost: host)))
    }

    private func synchronize(host: String, provider: ConversationProvider) throws {
        let destination = mirrorDirectory(host: host, provider: provider)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let remoteFolder = Self.remoteFolder(for: provider)
        let source = sourceHomeOverride.map { "\($0)/\(remoteFolder)/" } ?? "\(host):\(remoteFolder)/"

        guard let result = BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/rsync",
            arguments: Self.rsyncArguments(for: provider, source: source, destination: destination.path + "/"),
            includesStandardError: true,
            timeout: 600
        ) else { throw RemoteSessionMirrorError.couldNotRun(host: host) }

        switch result.exitStatus {
        case 0:
            return
        case 23 where result.output.contains("No such file or directory"):
            // The tool was never used on this host.
            try? FileManager.default.removeItem(at: destination)
        case RemoteHostCommandRunner.connectionFailureExitStatus:
            // rsync passes on the exit status of the `ssh` it runs.
            throw RemoteSessionMirrorError.sshFailed(host: host)
        case _ where result.output.contains("rsync: command not found") || result.output.contains("rsync: not found"):
            throw RemoteSessionMirrorError.rsyncMissingOnHost(host: host)
        default:
            let lastLine = result.output.split(separator: "\n").last.map(String.init) ?? "exit status \(result.exitStatus)"
            throw RemoteSessionMirrorError.rsyncFailed(host: host, output: lastLine)
        }
    }

    /// No `--prune-empty-dirs`: it drops a project folder whose last session was deleted from the transfer,
    /// and `--delete` then never removes that session from the mirror.
    static func rsyncArguments(for provider: ConversationProvider, source: String, destination: String) -> [String] {
        [
            "--archive", "--delete",
            "-e", "ssh -o BatchMode=yes -o ConnectTimeout=10",
        ]
            + includedPatterns(for: provider).map { "--include=\($0)" }
            + ["--exclude=*", source, destination]
    }

    /// Only the files the adapters read; Claude Code's subagent transcripts and caches stay on the host.
    static func includedPatterns(for provider: ConversationProvider) -> [String] {
        switch provider {
        case .claude:
            ["/projects/", "/projects/*/", "/projects/*/*.jsonl", "/projects/*/sessions-index.json"]
        case .codex:
            ["/session_index.jsonl", "/sessions/", "/sessions/**/", "/sessions/**/rollout-*.jsonl"]
        case .antigravity:
            []
        }
    }

    /// Relative to the remote home directory.
    static func remoteFolder(for provider: ConversationProvider) -> String {
        switch provider {
        case .claude: ".claude"
        case .codex: ".codex"
        case .antigravity: ".gemini/antigravity-cli"
        }
    }

    private static func mirroredFolderName(for provider: ConversationProvider) -> String {
        switch provider {
        case .claude: "claude"
        case .codex: "codex"
        case .antigravity: "antigravity"
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
