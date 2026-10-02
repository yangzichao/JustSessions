import Darwin
import Foundation
import Testing
@testable import JustSessions

@MainActor
struct BundledTmuxMigrationTests {
    @Test func aBundledClientCanReturnToWorkStartedByTheInstalledTmux() async throws {
        guard let runtimePath = ProcessInfo.processInfo.environment["JUSTSESSIONS_TEST_TMUX_RUNTIME"],
              let installedPath = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"].first(where: FileManager.default.isExecutableFile(atPath:)),
              let sandbox = try ThisMacTmuxSandbox.make(tmuxPathOverride: installedPath) else { return }
        defer { sandbox.tearDown() }
        let sessionName = "justsessions-claude-migration"
        _ = sandbox.tmuxOutput(["-f", "/dev/null", "new-session", "-d", "-s", sessionName, "--", "/bin/sleep", "60"])
        let originalProcessID = try #require(sandbox.server.paneProcessIDsBySessionName()[sessionName])
        let resolver = NativeCLICommandResolver(
            searchDirectories: [sandbox.binaryDirectory.path], inheritedEnvironment: sandbox.environment,
            bundledTmuxDirectory: URL(fileURLWithPath: runtimePath)
        )
        let selected = try #require(resolver.refreshThisMacTmuxServer())
        #expect(selected.appSessionPaneProcessIDs()[sessionName] == originalProcessID)
        #expect(kill(originalProcessID, 0) == 0)

        let client = try sandbox.startClient(selected.command(
            attachingTo: sessionName, running: sandbox.cliCommand(URL(fileURLWithPath: "/bin/sleep"), arguments: ["60"])
        ))
        defer { if client.isRunning { client.terminate() } }
        #expect(await sandbox.waitUntil { sandbox.tmuxOutput(["list-clients", "-F", "#{session_name}"]) == sessionName + "\n" })
        #expect(selected.appSessionPaneProcessIDs()[sessionName] == originalProcessID)
    }
}
