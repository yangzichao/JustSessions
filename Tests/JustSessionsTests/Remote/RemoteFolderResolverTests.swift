import Foundation
import Testing
@testable import JustSessions

struct RemoteFolderResolverTests {
    /// Runs the lookup in a local shell that starts in a temporary home folder, the way `ssh host <command>` would.
    @Test func resolvesHomeRelativeAbsoluteAndSymlinkedFolders() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        let app = home.appendingPathComponent("code/my app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent("app-link"), withDestinationURL: app)
        let resolver = RemoteFolderResolver(runner: localShell(home: home))
        let resolvedApp = physicalPath(of: app)

        #expect(try resolver.resolvedPath(of: "~/code/my app", host: "devbox") == resolvedApp)
        #expect(try resolver.resolvedPath(of: "code/my app", host: "devbox") == resolvedApp)
        #expect(try resolver.resolvedPath(of: "~/app-link", host: "devbox") == resolvedApp)
        #expect(try resolver.resolvedPath(of: app.path, host: "devbox") == resolvedApp)
        #expect(try resolver.resolvedPath(of: "~", host: "devbox") == physicalPath(of: home))
        #expect(throws: RemoteFolderResolutionError.missingFolder(host: "devbox", folder: "~/missing")) {
            try resolver.resolvedPath(of: "~/missing", host: "devbox")
        }
    }

    @Test func linesAShellProfilePrintsAreSkipped() throws {
        let recorder = RemoteCommandRecorder()
        let resolver = RemoteFolderResolver(runner: recorder.runner(answering: (0, "Welcome to devbox\n/home/me/app\n")))

        #expect(try resolver.resolvedPath(of: "~/app", host: "devbox") == "/home/me/app")
        #expect(recorder.commands.map(\.host) == ["devbox"])
        #expect(recorder.commands.map(\.command) == [#"sh -c 'cd -- "$1" && pwd -P' sh 'app'"#])
    }

    @Test func connectionProblemsAreReportedAsSuch() {
        let unreachable = RemoteFolderResolver(runner: RemoteCommandRecorder().runner(answering: (255, "Connection refused")))
        #expect(throws: RemoteFolderResolutionError.sshFailed(host: "devbox")) {
            try unreachable.resolvedPath(of: "/srv/app", host: "devbox")
        }
        let timedOut = RemoteFolderResolver(runner: RemoteCommandRecorder().runner(answering: nil))
        #expect(throws: RemoteFolderResolutionError.couldNotRun(host: "devbox")) {
            try timedOut.resolvedPath(of: "/srv/app", host: "devbox")
        }
    }

    /// What `getcwd` reports, which is what the CLI records. Unlike `resolvingSymlinksInPath`, it keeps `/private`.
    private func physicalPath(of folder: URL) -> String {
        guard let resolvedPath = realpath(folder.path, nil) else { return folder.path }
        defer { free(resolvedPath) }
        return String(cString: resolvedPath)
    }

    private func localShell(home: URL) -> RemoteHostCommandRunner {
        RemoteHostCommandRunner { _, command, _ in
            BoundedProcessRunner.result(
                ofExecutable: "/bin/sh",
                arguments: ["-c", #"cd "$HOME" && "# + command],
                environment: ["HOME": home.path, "PATH": "/usr/bin:/bin"],
                includesStandardError: true,
                timeout: 20
            )
        }
    }
}
