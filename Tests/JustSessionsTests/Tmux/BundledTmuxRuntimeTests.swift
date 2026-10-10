import Foundation
import Testing
@testable import JustSessions

struct BundledTmuxRuntimeTests {
    @Test func usesTheBundledRuntimeWithoutAnInstalledTmux() throws {
        let fixture = try BundledTmuxFixture()
        defer { fixture.tearDown() }
        try fixture.writeTmux(in: fixture.runtime.appendingPathComponent("bin"), version: "3.7c")
        let resolver = fixture.resolver

        #expect(resolver.executablePath(named: "tmux") == nil)
        #expect(resolver.refreshThisMacTmuxServer()?.executablePath == fixture.runtime.appendingPathComponent("bin/tmux").path)
        #expect(resolver.thisMacTmuxServer()?.terminfoDirectory == fixture.runtime.appendingPathComponent("share/terminfo").path)
    }

    @Test func preservesAnInstalledTmuxThatAlreadyRunsWork() throws {
        let fixture = try BundledTmuxFixture()
        defer { fixture.tearDown() }
        try fixture.writeTmux(in: fixture.runtime.appendingPathComponent("bin"), version: "3.7c")
        let installed = try fixture.writeTmux(in: fixture.installedDirectory, version: "3.6a", hasRunningSessions: true)
        let resolver = fixture.resolver

        #expect(resolver.refreshThisMacTmuxServer()?.executablePath == installed.path)
        #expect(resolver.thisMacTmuxServer()?.executablePath == installed.path)

        // Once the old server exits, new work uses the bundled runtime. Probing never kills or restarts it.
        try fixture.writeTmux(in: fixture.installedDirectory, version: "3.6a")
        #expect(resolver.refreshThisMacTmuxServer()?.executablePath == fixture.runtime.appendingPathComponent("bin/tmux").path)
    }

    @Test func aMissingBundledTerminalDatabaseFallsBackToInstalledTmux() throws {
        let fixture = try BundledTmuxFixture()
        defer { fixture.tearDown() }
        try fixture.writeTmux(in: fixture.runtime.appendingPathComponent("bin"), version: "3.7c")
        try FileManager.default.removeItem(at: fixture.runtime.appendingPathComponent("share/terminfo"))
        let installed = try fixture.writeTmux(in: fixture.installedDirectory, version: "3.6a")

        #expect(fixture.resolver.refreshThisMacTmuxServer()?.executablePath == installed.path)
    }

    @Test func bundledTerminfoReachesBothTheClientAndItsCLIPane() {
        let server = ThisMacTmuxServer(executablePath: "/App/Tmux/bin/tmux", environment: [:], terminfoDirectory: "/App/Tmux/share/terminfo")
        let command = server.command(attachingTo: "justsessions-claude-test", running: NativeCLICommand(
            executablePath: "/bin/claude", arguments: [], workingDirectory: "/tmp",
            environment: ["TERM=xterm-256color", "TERMINFO_DIRS=/custom/terminfo"]
        ))

        #expect(command.environmentVariables["TERMINFO_DIRS"] == "/App/Tmux/share/terminfo:/custom/terminfo:/usr/share/terminfo")
        #expect(command.arguments.contains("TERMINFO_DIRS=/App/Tmux/share/terminfo:/custom/terminfo:/usr/share/terminfo"))
    }

    /// GhosttyTerminal sets it in the app's own environment; see `GhosttyAppEnvironment`.
    @Test(arguments: [nil, "/App/Tmux/share/terminfo"])
    func ghosttysResourcesDirectoryReachesNeitherTheTmuxServerNorItsPanes(terminfoDirectory: String?) {
        let server = ThisMacTmuxServer(executablePath: "/App/Tmux/bin/tmux", environment: [:], terminfoDirectory: terminfoDirectory)
        let ghosttyVariable = "GHOSTTY_RESOURCES_DIR=/App/Ghostty"
        let command = server.command(attachingTo: "justsessions-claude-test", running: NativeCLICommand(
            executablePath: "/bin/claude", arguments: [], workingDirectory: "/tmp",
            environment: ["TERM=xterm-256color", ghosttyVariable]
        ))

        #expect(server.runtimeEnvironment(from: ["GHOSTTY_RESOURCES_DIR": "/App/Ghostty"])["GHOSTTY_RESOURCES_DIR"] == nil)
        #expect(command.environmentVariables["GHOSTTY_RESOURCES_DIR"] == nil)
        #expect(!command.arguments.contains(ghosttyVariable))
    }
}
