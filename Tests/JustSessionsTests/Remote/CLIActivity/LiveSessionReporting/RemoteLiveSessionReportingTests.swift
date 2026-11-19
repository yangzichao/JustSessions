import Foundation
import Testing

@testable import JustSessions

/// A Pi or OpenCode tab's tmux session on an SSH host writes the app's extension to the host and starts the CLI with
/// it, and the extension puts what the CLI does in the tab's title; see `RemoteLiveSessionReporting`. Runs the tab's
/// command against a real tmux on this Mac, with a private tmux server and home folder. Skipped where tmux is not
/// installed, and the tests that run the extension where `node` is not.
@Suite(.oneTmuxSandboxAtATime)
struct RemoteLiveSessionReportingTests {
    @Test func piStartsWithTheExtensionTheTabWroteToTheHost() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.addProgram(named: "pi", script: Self.recordingLaunch)
        let client = try sandbox.startClient(Self.tabCommand(.pi, in: sandbox))
        defer { client.terminate() }

        let launch = try #require(Self.waitForLaunch(in: sandbox))
        let extensionFile = Self.hostFolder(of: .pi, in: sandbox).appendingPathComponent(PiLiveSessionExtension.fileName)
        #expect(launch.arguments == ["--extension", extensionFile.path, "--session", "abc"])
        #expect(launch.activityOption == RemoteCLIActivityTitle.optionName)
        #expect(try String(contentsOf: extensionFile, encoding: .utf8) == PiLiveSessionExtension.source)
    }

    @Test func openCodeLoadsThePluginThroughATUIConfigurationBesideIt() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.addProgram(named: "opencode", script: Self.recordingLaunch)
        let client = try sandbox.startClient(Self.tabCommand(.opencode, in: sandbox))
        defer { client.terminate() }

        let launch = try #require(Self.waitForLaunch(in: sandbox))
        let folder = Self.hostFolder(of: .opencode, in: sandbox)
        #expect(launch.arguments == ["--session", "abc"])
        #expect(launch.activityOption == RemoteCLIActivityTitle.optionName)
        #expect(launch.tuiConfiguration == folder.appendingPathComponent("tui.json").path)
        #expect(
            try String(contentsOf: folder.appendingPathComponent("tui.json"), encoding: .utf8)
                == #"{"plugin":["./justsessions-live-session.js"]}"# + "\n")
        let pluginFile = folder.appendingPathComponent(OpenCodeLiveSessionPlugin.fileName)
        #expect(try String(contentsOf: pluginFile, encoding: .utf8) == OpenCodeLiveSessionPlugin.source)
    }

    /// Pi would refuse to start with an extension that isn't there.
    @Test(arguments: [ConversationProvider.pi, .opencode])
    func aHostWhoseHomeCantBeWrittenToStartsTheCLIWithoutTheExtension(provider: ConversationProvider) throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.addProgram(named: provider.executableName, script: Self.recordingLaunch)
        // A file where the folder would go.
        try "".write(to: sandbox.root.appendingPathComponent(".cache"), atomically: true, encoding: .utf8)
        let client = try sandbox.startClient(Self.tabCommand(provider, in: sandbox))
        defer { client.terminate() }

        let launch = try #require(Self.waitForLaunch(in: sandbox))
        #expect(launch.arguments == ["--session", "abc"])
        #expect(launch.activityOption.isEmpty)
        #expect(launch.tuiConfiguration.isEmpty)
    }

    @Test func piTellsTheTabWhatItDoes() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory,
            let node = ExtensionHostStandIns.installedNodePath
        else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try Self.addStandIn(named: "pi", running: ExtensionHostStandIns.pi, with: node, to: sandbox)
        let output = sandbox.root.appendingPathComponent("client.log")
        let client = try sandbox.startClient(Self.tabCommand(.pi, in: sandbox), recordingOutputTo: output)
        defer { client.terminate() }
        #expect(sandbox.waitUntil { TerminalTitlesSent.lastActivity(inOutputFile: output, of: .pi) == .idle })

        // A prompt's title is one line in the tab's title, and may end in tmux's command separator.
        let steps: [(String, CLIActivity)] = [
            ("agent_start", .working),
            ("ui_prompt_start\tAllow rm\u{07}-rf build;", .needsInput(reason: "Allow rm -rf build;")),
            ("ui_prompt_end\tAllow rm\u{07}-rf build;", .working),
            ("agent_settled", .idle),
        ]
        for index in steps.indices {
            try Self.setSteps(steps[...index].map(\.0), in: sandbox)
            let activity = steps[index].1
            #expect(sandbox.waitUntil { TerminalTitlesSent.lastActivity(inOutputFile: output, of: .pi) == activity }, "\(activity)")
        }
    }

    @Test func openCodeTellsTheTabWhatTheSessionOnScreenDoes() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory,
            let node = ExtensionHostStandIns.installedNodePath
        else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try Self.addStandIn(named: "opencode", running: ExtensionHostStandIns.openCode, with: node, to: sandbox)
        let output = sandbox.root.appendingPathComponent("client.log")
        let client = try sandbox.startClient(Self.tabCommand(.opencode, in: sandbox), recordingOutputTo: output)
        defer { client.terminate() }

        let steps: [(String, CLIActivity)] = [
            (#"{"session":"ses_1","status":"busy","permissions":0}"#, .working),
            (#"{"session":"ses_1","status":"busy","permissions":1}"#, .needsInput(reason: "permission")),
            (#"{"session":"ses_1","status":"idle","permissions":0}"#, .idle),
        ]
        for index in steps.indices {
            try Self.setSteps(steps[...index].map(\.0), in: sandbox)
            let activity = steps[index].1
            #expect(sandbox.waitUntil { TerminalTitlesSent.lastActivity(inOutputFile: output, of: .opencode) == activity }, "\(activity)")
        }

        // Its home screen shows no session, and the tab's title is the CLI's own again.
        try Self.setSteps(steps.map(\.0) + [#"{"session":null,"status":"idle","permissions":0}"#], in: sandbox)
        #expect(
            sandbox.waitUntil {
                let title = TerminalTitlesSent.titles(inOutputFile: output).last ?? ""
                return !title.isEmpty && !title.hasPrefix(RemoteCLIActivityTitle.titlePrefix)
            })
    }

    /// Records its arguments, and the two variables a tab's login shell may set for the extension, then waits.
    private static let recordingLaunch = #"""
        {
          printf '%s\n' "$@"
          printf 'option=%s\ntui=%s\n' "$JUSTSESSIONS_TMUX_ACTIVITY_OPTION" "$OPENCODE_TUI_CONFIG"
        } > "$HOME/launch.partial" && mv "$HOME/launch.partial" "$HOME/launch"
        exec sleep 600
        """#

    private struct Launch {
        let arguments: [String]
        let activityOption: String
        let tuiConfiguration: String
    }

    private static func waitForLaunch(in sandbox: TmuxSandbox) -> Launch? {
        let file = sandbox.root.appendingPathComponent("launch")
        guard sandbox.waitUntil({ FileManager.default.fileExists(atPath: file.path) }),
            let text = try? String(contentsOf: file, encoding: .utf8)
        else { return nil }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).dropLast()
        guard lines.count >= 2 else { return nil }
        return Launch(
            arguments: Array(lines.dropLast(2)),
            activityOption: String(lines[lines.endIndex - 2].dropFirst("option=".count)),
            tuiConfiguration: String(lines[lines.endIndex - 1].dropFirst("tui=".count))
        )
    }

    private static func hostFolder(of provider: ConversationProvider, in sandbox: TmuxSandbox) -> URL {
        sandbox.root.appendingPathComponent(RemoteLiveSessionReporting.folder).appendingPathComponent(provider.executableName)
    }

    private static func addStandIn(named name: String, running script: String, with node: String, to sandbox: TmuxSandbox) throws {
        let scriptFile = sandbox.root.appendingPathComponent("\(name)-stand-in.mjs")
        try script.write(to: scriptFile, atomically: true, encoding: .utf8)
        try sandbox.addProgram(named: name, script: "exec \(ShellQuoting.quoted(node)) \(ShellQuoting.quoted(scriptFile.path)) \"$@\"")
    }

    private static func setSteps(_ steps: [String], in sandbox: TmuxSandbox) throws {
        let file = sandbox.root.appendingPathComponent(ExtensionHostStandIns.stepsFileName)
        try (steps.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    private static func tabCommand(_ provider: ConversationProvider, in sandbox: TmuxSandbox) -> String {
        RemoteCLICommandBuilder.remoteCommand(
            provider: provider,
            projectPath: sandbox.project.path,
            arguments: ["--session", "abc"],
            tmuxSessionName: TmuxSessionName.unique(for: provider)
        )
    }
}
