import Foundation
import Testing

@testable import JustSessions

/// A remote Antigravity tab's relay, which reads the conversation database the CLI holds open and puts what it does in
/// the tab's title; see `RemoteAntigravityActivityRelay`. Runs the tab's command against a real tmux on this Mac, with a
/// private tmux server and home folder, and an `agy` stand-in that keeps a database as Antigravity CLI 1.3.6 does: its
/// `steps`, and an `executor_metadata` row naming each ended turn's last step. On this Mac the relay finds the database
/// with `lsof`; Linux's `/proc` was checked live. Skipped where tmux or `python3` is missing.
@Suite(.oneTmuxSandboxAtATime)
struct RemoteAntigravityActivityRelayTests {
    @Test func readsTheNamesTheRelayKeeps() {
        #expect(RemoteAntigravityActivityRelay.activity(named: "working") == .working)
        #expect(RemoteAntigravityActivityRelay.activity(named: "waiting") == .needsInput(reason: nil))
        #expect(RemoteAntigravityActivityRelay.activity(named: "idle") == .idle)
        #expect(RemoteAntigravityActivityRelay.activity(named: "busy") == nil)
        let prefix = RemoteCLIActivityTitle.titlePrefix
        #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: prefix + "waiting:", of: .antigravity) == .needsInput(reason: nil))
    }

    @Test func theTabsTitleSaysWhatTheConversationDatabaseSays() throws {
        guard let sandbox = try Self.sandboxWithAntigravity() else { return }
        defer { sandbox.tearDown() }
        let output = sandbox.root.appendingPathComponent("client.log")
        let client = try sandbox.startClient(tabCommand(sandbox), recordingOutputTo: output)
        defer { client.terminate() }

        let states: [(String, CLIActivity)] = [
            ("idle", .idle), ("working", .working), ("waiting", .needsInput(reason: nil)), ("idle", .idle),
        ]
        for (state, activity) in states {
            try Self.setState(state, in: sandbox)
            #expect(sandbox.waitUntil { TerminalTitlesSent.lastActivity(inOutputFile: output, of: .antigravity) == activity }, "\(state)")
        }
    }

    @Test func aTurnAnEarlierCLILeftOpenIsIdle() throws {
        guard let sandbox = try Self.sandboxWithAntigravity() else { return }
        defer { sandbox.tearDown() }
        let tmuxName = TmuxSessionName.unique(for: .antigravity)
        try Self.setState("left-open", in: sandbox)
        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName: tmuxName))
        defer { client.terminate() }

        #expect(sandbox.waitUntil { Self.relayedActivity(of: tmuxName, in: sandbox) == "idle:" })
        try Self.setState("working", in: sandbox)
        #expect(sandbox.waitUntil { Self.relayedActivity(of: tmuxName, in: sandbox) == "working:" })
    }

    @Test func itEndsWithTheCLI() throws {
        guard let sandbox = try Self.sandboxWithAntigravity() else { return }
        defer { sandbox.tearDown() }
        let tmuxName = TmuxSessionName.unique(for: .antigravity)
        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName: tmuxName))
        defer { client.terminate() }
        #expect(sandbox.waitUntil { Self.relayedActivity(of: tmuxName, in: sandbox) == "idle:" })
        let target = ShellQuoting.quoted("=" + tmuxName + ":")
        let panePID = try #require(
            Int32(
                sandbox.run("tmux display-message -p -t \(target) '#{pane_pid}'")
                    .trimmingCharacters(in: .newlines)))
        #expect(Self.relayCount(inProcessGroup: panePID) == 1)

        _ = sandbox.run(#"touch "$HOME/agy-exit""#)

        #expect(sandbox.waitUntil { !sandbox.hasTmuxSession(tmuxName) })
        #expect(sandbox.waitUntil { Self.relayCount(inProcessGroup: panePID) == 0 })
    }

    /// Keeps `conversations/<id>.db` open, with the steps and ended turns `$HOME/agy-state` asks for: `idle`, `working`
    /// (a step after the last ended turn), `waiting` (that step waits for approval, status 9), or `left-open` (that
    /// step is an hour old), until `$HOME/agy-exit` appears.
    private static let agyStandIn = #"""
        import os, sqlite3, time

        HOME = os.environ["HOME"]
        folder = os.path.join(HOME, ".gemini/antigravity-cli/conversations")
        os.makedirs(folder, exist_ok=True)
        database = sqlite3.connect(os.path.join(folder, "11111111-2222-4333-8444-555555555555.db"), isolation_level=None)
        database.execute("CREATE TABLE IF NOT EXISTS steps (idx INTEGER PRIMARY KEY, status INTEGER, step_payload BLOB)")
        database.execute("CREATE TABLE IF NOT EXISTS executor_metadata (idx INTEGER PRIMARY KEY, data BLOB)")

        def varint(number):
            out = b""
            while True:
                byte = number & 0x7F
                number >>= 7
                if number:
                    out += bytes([byte | 0x80])
                else:
                    return out + bytes([byte])

        # A protobuf Timestamp's seconds and nanoseconds, as Antigravity writes them: the relay compares the step's
        # time with its own start, which is less than a second earlier when a test writes a turn right away.
        def payload(seconds):
            timestamp = b"\x08" + varint(int(seconds)) + b"\x10" + varint(int(seconds % 1 * 1e9))
            inner = b"\x0a" + varint(len(timestamp)) + timestamp
            return b"\x2a" + varint(len(inner)) + inner

        def write(state):
            database.execute("DELETE FROM steps")
            database.execute("DELETE FROM executor_metadata")
            now = time.time()
            database.execute("INSERT INTO steps VALUES (0, 3, ?), (1, 3, ?)", (payload(now - 60), payload(now - 59)))
            database.execute("INSERT INTO executor_metadata VALUES (0, ?)", (b"\x18\x01",))
            if state in ("working", "waiting", "left-open"):
                started = now - 3600 if state == "left-open" else now
                database.execute("INSERT INTO steps VALUES (2, ?, ?)", (9 if state == "waiting" else 3, payload(started)))

        shown = None
        while not os.path.exists(os.path.join(HOME, "agy-exit")):
            try:
                state = open(os.path.join(HOME, "agy-state")).read().strip()
            except OSError:
                state = "idle"
            if state != shown:
                write(state)
                shown = state
            time.sleep(0.1)
        database.close()
        """#

    private static func sandboxWithAntigravity() throws -> TmuxSandbox? {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory,
            FileManager.default.isExecutableFile(atPath: "/usr/bin/python3")
        else { return nil }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        try agyStandIn.write(to: sandbox.root.appendingPathComponent("agy-stand-in.py"), atomically: true, encoding: .utf8)
        try sandbox.addProgram(named: "agy", script: #"exec python3 "$HOME/agy-stand-in.py""#)
        try setState("idle", in: sandbox)
        return sandbox
    }

    private static func setState(_ state: String, in sandbox: TmuxSandbox) throws {
        try state.write(to: sandbox.root.appendingPathComponent("agy-state"), atomically: true, encoding: .utf8)
    }

    private static func relayedActivity(of tmuxName: String, in sandbox: TmuxSandbox) -> String {
        let target = ShellQuoting.quoted("=" + tmuxName + ":")
        return sandbox.run("tmux show-options -wqv -t \(target) \(RemoteCLIActivityTitle.optionName)")
            .trimmingCharacters(in: .newlines)
    }

    /// Relays started in one pane, which stay in its process group as the sandbox's login shell has no job control; see
    /// `RemoteClaudeActivityRelayTests.relayCount(inProcessGroup:)`. `ps` writes the script's later lines on lines of
    /// their own, so only its first line is matched, and names the interpreter by its full path, as Homebrew's
    /// `Python.app`, so only what it was started with is.
    private static func relayCount(inProcessGroup processGroupID: Int32) -> Int {
        let processes =
            BoundedProcessRunner.output(
                ofExecutable: "/bin/ps", arguments: ["-ax", "-ww", "-o", "pgid=,command="], environment: [:], timeout: 10
            ) ?? ""
        return processes.split(separator: "\n").filter { line in
            let fields = line.split(separator: " ", maxSplits: 1)
            return fields.count == 2 && Int32(fields[0]) == processGroupID
                && fields[1].contains(" -c import os, re, sqlite3")
        }.count
    }

    private func tabCommand(_ sandbox: TmuxSandbox, tmuxName: String = TmuxSessionName.unique(for: .antigravity)) -> String {
        RemoteCLICommandBuilder.remoteCommand(
            provider: .antigravity,
            projectPath: sandbox.project.path,
            arguments: ["--conversation", "11111111-2222-4333-8444-555555555555"],
            tmuxSessionName: tmuxName
        )
    }
}
