import Foundation
@testable import JustSessions

/// A folder that stands in for an SSH host's home, with an OpenCode database in its standard place, a fake login
/// shell, and the host's mirror on this Mac.
struct RemoteOpenCodeFixture {
    static let projectPath = "/srv/Bob's paper; $dollar"

    let root: URL
    let home: URL
    let binaryDirectory: URL
    let hostDatabase: OpenCodeDatabaseFixture
    let cacheRoot: URL

    init() throws {
        root = try makeTemporaryDirectory()
        home = root.appendingPathComponent("remote home")
        binaryDirectory = root.appendingPathComponent("bin")
        cacheRoot = root.appendingPathComponent("cache")
        let dataDirectory = home.appendingPathComponent(".local/share/opencode")
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: binaryDirectory.appendingPathComponent("login-shell"))
        hostDatabase = try OpenCodeDatabaseFixture(file: dataDirectory.appendingPathComponent("opencode.db"))
        try hostDatabase.addSession(OpenCodeDeletionFixture.selectedSessionID, directory: Self.projectPath, title: "Delete me")
        try hostDatabase.addSession(OpenCodeDeletionFixture.subagentSessionID, directory: Self.projectPath, parentID: OpenCodeDeletionFixture.selectedSessionID)
        try hostDatabase.addSession(OpenCodeDeletionFixture.retainedSessionID, directory: Self.projectPath, title: "Keep me")
        try hostDatabase.addUserPrompt("msg_selected", session: OpenCodeDeletionFixture.selectedSessionID, createdAt: 1, text: "Delete me")
        try hostDatabase.addUserPrompt("msg_subagent", session: OpenCodeDeletionFixture.subagentSessionID, createdAt: 1, text: "Subtask")
        try hostDatabase.addUserPrompt("msg_retained", session: OpenCodeDeletionFixture.retainedSessionID, createdAt: 1, text: "Keep me")
    }

    /// Copies from the stand-in home as the host's snapshot would.
    var discovery: RemoteSessionDiscovery {
        RemoteSessionDiscovery(mirror: RemoteSessionMirror(cacheRoot: cacheRoot, sourceHomeOverride: home.path))
    }

    var mirrorDatabase: URL {
        RemoteSessionMirror(cacheRoot: cacheRoot).mirrorDirectory(host: "devbox", provider: .opencode).appendingPathComponent("opencode.db")
    }

    func mirroredConversation(_ sessionID: String = OpenCodeDeletionFixture.selectedSessionID) throws -> Conversation {
        guard let conversation = try discovery.discover(host: "devbox").first(where: { $0.provider == .opencode && $0.sessionID == sessionID }) else {
            throw NSError(domain: "RemoteOpenCodeFixture", code: 1)
        }
        return conversation
    }

    func deletion(running script: String = OpenCodeDeletionFixture.deletingScript, environment: [String: String] = [:]) throws -> RemoteConversationDeletion {
        try writeExecutableScript(script, to: binaryDirectory.appendingPathComponent("opencode"))
        return RemoteConversationDeletion(runner: runner(environment: environment), mirror: RemoteSessionMirror(cacheRoot: cacheRoot))
    }

    /// Runs commands as `ssh` would on the host, through the fake login shell.
    func runner(environment: [String: String] = [:]) -> RemoteHostCommandRunner {
        let hostEnvironment = [
            "HOME": home.path,
            "SHELL": binaryDirectory.appendingPathComponent("login-shell").path,
            "PATH": binaryDirectory.path + ":/usr/bin:/bin",
        ].merging(environment) { $1 }
        return RemoteHostCommandRunner { _, command, _ in
            BoundedProcessRunner.result(
                ofExecutable: "/bin/sh",
                arguments: ["-c", command],
                environment: hostEnvironment,
                includesStandardError: true,
                timeout: 20
            )
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
