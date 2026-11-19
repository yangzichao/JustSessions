import Foundation
import Testing

@testable import JustSessions

/// A remote Claude Code tab's relay, which reads the CLI's record in the host's live registry and puts it in the tab's
/// title; see `RemoteClaudeActivityRelay`. Runs the tab's command against a real tmux on this Mac, with a private tmux
/// server and home folder, and a `claude` stand-in that keeps a record as Claude Code 2.1.300 does on Linux. Skipped
/// where tmux is not installed.
@Suite(.oneTmuxSandboxAtATime)
struct RemoteClaudeActivityRelayTests {
    @Test func theTabsTitleSaysWhatTheCLIsRecordSays() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.replaceCLI(withScript: Self.claudeKeepingARecord)
        let output = sandbox.root.appendingPathComponent("client.log")
        let client = try sandbox.startClient(tabCommand(sandbox), recordingOutputTo: output)
        defer { client.terminate() }

        let records: [(String, CLIActivity)] = [
            (#""status":"busy""#, .working),
            (#""status":"waiting","waitingFor":"input needed""#, .needsInput(reason: "input needed")),
            (#""status":"idle""#, .idle),
        ]
        for (record, activity) in records {
            try Self.setRecord(record, in: sandbox)
            #expect(sandbox.waitUntil { TerminalTitlesSent.lastActivity(inOutputFile: output, of: .claude) == activity }, "\(record)")
        }
    }

    @Test func itReadsTheRegistryWhereTheHostsStartupFilesPutIt() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(
            tmuxDirectory: tmuxDirectory,
            loginShellStartup: #"export CLAUDE_CONFIG_DIR="$HOME/Claude config""#
        )
        defer { sandbox.tearDown() }
        try sandbox.replaceCLI(withScript: Self.claudeKeepingARecord)
        let tmuxName = TmuxSessionName.unique(for: .claude)
        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName: tmuxName))
        defer { client.terminate() }

        try Self.setRecord(#""status":"busy""#, in: sandbox)

        #expect(sandbox.waitUntil { Self.relayedRecord(of: tmuxName, in: sandbox) == "busy:" })
        #expect(FileManager.default.fileExists(atPath: sandbox.root.appendingPathComponent("Claude config/sessions").path))
    }

    /// As after the tab closed with Keep running, or its connection dropped.
    @Test func itGoesOnWithNoTabAndAReattachStartsNoSecondOne() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.replaceCLI(withScript: Self.claudeKeepingARecord)
        let tmuxName = TmuxSessionName.unique(for: .claude)
        try Self.setRecord(#""status":"busy""#, in: sandbox)
        let firstClient = try sandbox.startClient(tabCommand(sandbox, tmuxName: tmuxName))
        #expect(sandbox.waitUntil { Self.relayedRecord(of: tmuxName, in: sandbox) == "busy:" })
        firstClient.terminate()
        firstClient.waitUntilExit()

        try Self.setRecord(#""status":"idle""#, in: sandbox)
        #expect(sandbox.waitUntil { Self.relayedRecord(of: tmuxName, in: sandbox) == "idle:" })

        // The relay sets the option only when the record changes, and a new one would set it at once.
        let target = ShellQuoting.quoted("=" + tmuxName + ":")
        _ = sandbox.run("tmux set-option -w -t \(target) \(RemoteCLIActivityTitle.optionName) left-alone")
        let secondClient = try sandbox.startClient(tabCommand(sandbox, tmuxName: tmuxName))
        defer { secondClient.terminate() }
        #expect(sandbox.waitUntil { sandbox.run("tmux list-clients -t \(target)").contains("/dev/") })
        Thread.sleep(forTimeInterval: 1.5)
        #expect(Self.relayedRecord(of: tmuxName, in: sandbox) == "left-alone")
    }

    @Test func itEndsWithTheCLI() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.replaceCLI(withScript: Self.claudeKeepingARecord)
        let tmuxName = TmuxSessionName.unique(for: .claude)
        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName: tmuxName))
        defer { client.terminate() }
        try Self.setRecord(#""status":"busy""#, in: sandbox)
        #expect(sandbox.waitUntil { Self.relayedRecord(of: tmuxName, in: sandbox) == "busy:" })
        let target = ShellQuoting.quoted("=" + tmuxName + ":")
        let panePID = try #require(
            Int32(
                sandbox.run("tmux display-message -p -t \(target) '#{pane_pid}'")
                    .trimmingCharacters(in: .newlines)))
        #expect(Self.relayCount(inProcessGroup: panePID) == 1)

        _ = sandbox.run(#"touch "$HOME/claude-exit""#)

        #expect(sandbox.waitUntil { !sandbox.hasTmuxSession(tmuxName) })
        #expect(sandbox.waitUntil { Self.relayCount(inProcessGroup: panePID) == 0 })
    }

    @Test func namesAndSessionSwitchesReachTheTabWithoutAnActivityChange() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.replaceCLI(withScript: Self.claudeKeepingARecord)
        let output = sandbox.root.appendingPathComponent("client.log")
        let client = try sandbox.startClient(tabCommand(sandbox), recordingOutputTo: output)
        defer { client.terminate() }
        let name = "部署 \"quoted\" \\ #{pane_id}; $(touch should-not-exist)"
        let fields = try JSONSerialization.data(withJSONObject: ["status": "idle", "name": name, "nameSource": "user"])
        try Self.setRecord(String(decoding: fields, as: UTF8.self).dropFirst().dropLast().description, in: sandbox)

        #expect(sandbox.waitUntil { Self.lastSession(in: output)?.userChosenName == name })
        #expect(TerminalTitlesSent.lastActivity(inOutputFile: output, of: .claude) == .idle)
        #expect(!FileManager.default.fileExists(atPath: sandbox.project.appendingPathComponent("should-not-exist").path))

        let newID = UUID().uuidString.lowercased()
        try newID.write(to: sandbox.root.appendingPathComponent("claude-session-id"), atomically: true, encoding: .utf8)
        #expect(sandbox.waitUntil { Self.lastSession(in: output)?.sessionID == newID })
        #expect(Self.lastSession(in: output)?.userChosenName == name)

        // Metadata too large to relay must not leave the old idle record hiding a new busy state.
        let huge = #""status":"busy","name":"\#(String(repeating: "x", count: 9000))","nameSource":"user""#
        try Self.setRecord(huge, in: sandbox)
        #expect(sandbox.waitUntil { TerminalTitlesSent.lastActivity(inOutputFile: output, of: .claude) == .working })
        #expect(Self.lastSession(in: output) == nil)
    }

    @Test func aTranscriptRenameReachesTheTabWhenTheRegistryOmitsTheName() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.replaceCLI(withScript: Self.claudeKeepingARecord)
        let output = sandbox.root.appendingPathComponent("client.log")
        let client = try sandbox.startClient(tabCommand(sandbox), recordingOutputTo: output)
        defer { client.terminate() }
        try Self.setRecord(#""status":"idle""#, in: sandbox)
        #expect(sandbox.waitUntil { Self.lastSession(in: output)?.sessionID == Self.sessionID })
        let folder = sandbox.root.appendingPathComponent(".claude/projects/a project")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let transcript = folder.appendingPathComponent("\(Self.sessionID).jsonl")
        try #"{"type":"custom-title","customTitle":"Transcript ✓","sessionId":"\#(Self.sessionID)"}"#
            .write(to: transcript, atomically: true, encoding: .utf8)
        #expect(sandbox.waitUntil { Self.lastSession(in: output)?.userChosenName == "Transcript ✓" })

        // A large turn moves the title out of the tail. Its last name stays, but not after /clear.
        try String(repeating: "x", count: 70000).write(to: transcript, atomically: true, encoding: .utf8)
        Thread.sleep(forTimeInterval: 1.5)
        #expect(Self.lastSession(in: output)?.userChosenName == "Transcript ✓")
        let newID = UUID().uuidString.lowercased()
        try newID.write(to: sandbox.root.appendingPathComponent("claude-session-id"), atomically: true, encoding: .utf8)
        #expect(sandbox.waitUntil { Self.lastSession(in: output)?.sessionID == newID })
        #expect(Self.lastSession(in: output)?.userChosenName == nil)
    }

    private static let sessionID = "3dba4b81-0805-49c2-bbc7-84b61e334cbe"

    private static func lastSession(in output: URL) -> ClaudeLiveSessionRecord? {
        TerminalTitlesSent.titles(inOutputFile: output).last.flatMap(RemoteClaudeSessionTitle.record(inTerminalTitle:))
    }

    /// Keeps `$HOME/claude-record` in a registry record for its pane, rewritten in place as Claude Code may, until
    /// `$HOME/claude-exit` appears, then takes the record away as it does on exit.
    private static let claudeKeepingARecord = #"""
        #!/bin/sh
        location=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_id}.#{pane_id}')
        records=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions
        mkdir -p "$records"
        while [ ! -e "$HOME/claude-exit" ]; do
          session_id=\#(Self.sessionID)
          [ -f "$HOME/claude-session-id" ] && IFS= read -r session_id < "$HOME/claude-session-id"
          [ -f "$HOME/claude-record" ] && printf '{"pid":%s,"sessionId":"%s","tmux":"%s",%s,"updatedAt":1}' "$$" "$session_id" "$location" "$(cat "$HOME/claude-record")" > "$records/$$.json"
          sleep 0.1
        done
        rm -f "$records/$$.json"
        """#

    private static func setRecord(_ fields: String, in sandbox: TmuxSandbox) throws {
        try fields.write(to: sandbox.root.appendingPathComponent("claude-record"), atomically: true, encoding: .utf8)
    }

    private static func relayedRecord(of tmuxName: String, in sandbox: TmuxSandbox) -> String {
        let target = ShellQuoting.quoted("=" + tmuxName + ":")
        return sandbox.run("tmux show-options -wqv -t \(target) \(RemoteCLIActivityTitle.optionName)")
            .trimmingCharacters(in: .newlines)
    }

    /// Relays started in one pane. The sandbox's login shell has no job control, so the relay stays in the pane's
    /// process group, which tells it from other tests' relays.
    private static func relayCount(inProcessGroup processGroupID: Int32) -> Int {
        let processes =
            BoundedProcessRunner.output(
                ofExecutable: "/bin/ps",
                arguments: ["-ax", "-ww", "-o", "pgid=,command="],
                environment: [:],
                timeout: 10
            ) ?? ""
        return processes.split(separator: "\n").filter { line in
            let fields = line.split(separator: " ", maxSplits: 1)
            return fields.count == 2 && Int32(fields[0]) == processGroupID
                && fields[1].trimmingCharacters(in: .whitespaces).hasPrefix("sh -c (")
        }.count
    }

    private func tabCommand(_ sandbox: TmuxSandbox, tmuxName: String = TmuxSessionName.unique(for: .claude)) -> String {
        RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: sandbox.project.path,
            arguments: ["--resume", "abc"],
            tmuxSessionName: tmuxName
        )
    }
}
