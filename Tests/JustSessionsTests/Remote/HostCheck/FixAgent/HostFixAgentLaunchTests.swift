import Foundation
import Testing

@testable import JustSessions

@MainActor
struct HostFixAgentLaunchTests {
    @Test func onThisMacTheCLIGetsThePromptLastAndRunsWithoutTmux() throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: .swiftTerm)
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()

        try store.launchNewSession(provider: .codex, in: sandbox.projectLocation, initialPrompt: "Fix devbox", runsInTmux: false)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.tmuxSessionName == nil)
        #expect(tab.startsNewSession)
        #expect(tab.command.executablePath.hasSuffix("/codex"))
        #expect(tab.command.arguments.last == "Fix devbox")
    }

    @Test func onAnSSHHostTheCLIRunsInTheLoginShellWithoutTmux() throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: .swiftTerm)
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        let location = ProjectLocation(host: .ssh("devbox"), path: "/srv/project")

        try store.launchNewSession(provider: .codex, in: location, initialPrompt: "Fix devbox", runsInTmux: false)
        try store.launchNewSession(provider: .codex, in: location, initialPrompt: "Fix devbox")

        let (agentTab, tmuxTab) = (store.terminalSessions[store.terminalSessions.count - 2], store.terminalSessions.last!)
        #expect(agentTab.tmuxSessionName == nil)
        #expect(agentTab.command.arguments.last?.contains("tmux") == false)
        #expect(agentTab.command.arguments.last?.contains("'\\''Fix devbox'\\''") == true)
        #expect(tmuxTab.tmuxSessionName != nil)
        #expect(tmuxTab.command.arguments.last?.contains("tmux") == true)
    }

    @Test func thePromptReachesTheHostsCLIAsItWas() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bin = root.appendingPathComponent("bin")
        let project = root.appendingPathComponent("project")
        let received = root.appendingPathComponent("received")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        try writeExecutableScript(
            "#!/bin/sh\nfor argument; do last=$argument; done\nprintf '%s' \"$last\" > \(ShellQuoting.quoted(received.path))\n",
            to: bin.appendingPathComponent("codex")
        )
        let prompt = "Fix devbox's tmux.\n\n- Run `tmux ls` and \"$SHELL\"; don't \\ guess!\n* $(whoami) ${HOME} 100%"
        let remoteCommand = RemoteCLICommandBuilder.remoteCommand(
            provider: .codex,
            projectPath: project.path,
            arguments: ConversationProvider.codex.initialPromptArguments(prompt)
        )

        _ = BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", remoteCommand],
            environment: ["HOME": root.path, "SHELL": bin.appendingPathComponent("login-shell").path, "PATH": "\(bin.path):/usr/bin:/bin"],
            timeout: 10
        )

        #expect(try String(contentsOf: received, encoding: .utf8) == prompt)
    }
}
