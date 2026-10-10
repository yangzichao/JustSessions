import AppKit
import CoreImage
import Darwin
import Foundation
import GhosttyTerminal
import IOSurface
import Testing
@testable import JustSessions

/// Runs the real Claude Code and Codex CLIs installed on this Mac in a tab's terminal, and saves what each terminal
/// shows: a PNG and its screen text. Opt-in, since it runs the installed CLIs:
///
///     JUSTSESSIONS_LIVE_EVIDENCE=1 JUSTSESSIONS_LIVE_EVIDENCE_DIRECTORY=<folder for the evidence> \
///     CLAUDE_CONFIG_DIR="$(mktemp -d)" CODEX_HOME="$(mktemp -d)" \
///     JUSTSESSIONS_TEST_TMUX_RUNTIME="$(./Scripts/Tmux/build-runtime.sh)" swift test --filter LiveCLIEvidence
///
/// Each run gets a project folder, home folder, and CLI settings folders of its own under
/// `JUSTSESSIONS_LIVE_SCRATCH_DIRECTORY`, or else the temporary folder, so a CLI never reads or changes your own
/// sessions or settings, and shows its first-run or sign-in screen. A `ConversationStore` checks the installed `claude`'s
/// `--help` with the test process's environment, so the process's own `CLAUDE_CONFIG_DIR` and `CODEX_HOME` must point
/// at empty folders too. Set `JUSTSESSIONS_LIVE_SSH_HOST` to also open a tab on that SSH host. Each run's folders stay
/// afterwards, with what the CLIs wrote, for a look at the evidence.
@MainActor
@Suite(.serialized, .enabled(if: LiveCLIEvidenceSettings.isEnabled, "Runs the CLIs installed on this Mac; set JUSTSESSIONS_LIVE_EVIDENCE=1"))
struct LiveCLIEvidence {
    /// How long a CLI has to show its screen.
    fileprivate static let screenTimeout: Duration = .seconds(60)

    @Test(arguments: TerminalEngine.allCases)
    func claudeCodeRunsDirectlyInATab(_ engine: TerminalEngine) async throws {
        let claude = try #require(LiveCLI.claude.path, "No claude found in \(LiveCLI.claude.candidatePaths)")
        let run = try LiveCLIRun(name: "local-claude-\(engine.rawValue)")
        let tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: .claude,
            projectPath: run.project.path,
            action: .new,
            displayTitle: "Claude Code",
            command: NativeCLICommand(
                executablePath: claude,
                arguments: [],
                workingDirectory: run.project.path,
                environment: run.cliEnvironment(executableDirectory: (claude as NSString).deletingLastPathComponent)
            )
        )
        let window = LiveCLIWindow(showing: tab.terminalView)
        defer {
            tab.close()
            window.close()
        }

        tab.startIfNeeded()
        let processID = tab.processID
        try #require(processID > 0)
        try await run.waitForScreen(of: tab, toShow: "Claude Code")
        let snapshot = try #require(LiveCLISnapshot(of: tab.terminalView), "No image of the \(engine.rawValue) terminal")
        let screen = LiveCLIScreen.text(of: tab)
        let exit = await LiveCLIExit.pressControlCTwice(in: tab, window: window)

        try run.saveEvidence(
            named: "live-local-claude-\(engine.rawValue)",
            snapshot: snapshot,
            screen: screen,
            details: ["engine: \(engine.rawValue)", "command: \(claude)", "exit: \(exit.description)"]
        )
        #expect(exit.reaped, "Claude Code's process \(processID) was not reaped: \(exit.description)")
    }

    /// As the app runs a new Claude Code session: in a sandboxed tmux server, through `ConversationStore`.
    @Test func claudeCodeRunsInTmuxInAGhosttyTab() async throws {
        let claude = try #require(LiveCLI.claude.path, "No claude found in \(LiveCLI.claude.candidatePaths)")
        try LiveCLIRun.requireIsolatedProcessSettings()
        let sandbox = try #require(
            try ThisMacTmuxSandbox.make(),
            "No supported tmux; set JUSTSESSIONS_TEST_TMUX_RUNTIME=\"$(./Scripts/Tmux/build-runtime.sh)\""
        )
        defer { sandbox.tearDown() }
        // The sandbox's own server: its socket sits in the sandbox's folder, never in the app's.
        try #require(sandbox.environment["TMUX_TMPDIR"] == sandbox.root.path)
        let run = try LiveCLIRun(name: "tmux-claude-ghostty")
        try FileManager.default.createSymbolicLink(
            at: sandbox.binaryDirectory.appendingPathComponent("claude"),
            withDestinationURL: URL(fileURLWithPath: claude)
        )
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(
            adapters: [StaticConversationAdapter(discoveredConversations: [])],
            commandResolver: NativeCLICommandResolver(
                searchDirectories: [sandbox.binaryDirectory.path],
                inheritedEnvironment: sandbox.environment.merging(run.cliSettingsEnvironment) { $1 },
                bundledTmuxDirectory: nil
            ),
            userDefaults: settings.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            terminalEngineStore: try TerminalEngineStore.pinned(to: .ghostty),
            startsBackgroundPolling: false
        )
        defer { store.closeAllTerminals() }
        // Tabs run the CLI directly until a refresh has checked the tmux version.
        store.refreshThisMac()
        try #require(await sandbox.waitUntil { !store.isScanningThisMac })
        try #require(store.commandResolver.thisMacTmuxServer()?.executablePath == sandbox.server.executablePath)

        try store.launchNewSession(provider: .claude, in: ProjectLocation(host: .thisMac, path: run.project.path))

        let tab = try #require(store.terminalSessions.last)
        let tmuxSessionName = try #require(tab.tmuxSessionName)
        #expect(tab.engine == .ghostty)
        #expect(tab.terminalView is GhosttyTabTerminalView)
        let window = LiveCLIWindow(showing: tab.terminalView)
        defer { window.close() }
        tab.startIfNeeded()
        try await run.waitForScreen(of: tab, toShow: "Claude Code", diagnostics: { sandbox.launchDiagnostics(for: tab) })
        let snapshot = try #require(LiveCLISnapshot(of: tab.terminalView), "No image of the Ghostty terminal")
        let screen = LiveCLIScreen.text(of: tab)
        let cliProcessID = try #require(sandbox.server.paneProcessIDsBySessionName()[tmuxSessionName])
        let clientProcessID = tab.processID

        // Closing the tab and ending its tmux session, as Close and End does.
        store.closeTerminal(tab.id, endingTmuxSession: true)
        let sessionEnded = await sandbox.waitUntil { !sandbox.server.sessionNames().contains(tmuxSessionName) }
        let cliEnded = await LiveCLIExit.waitUntilReaped(cliProcessID)
        let clientReaped = await LiveCLIExit.waitUntilReaped(clientProcessID)

        try run.saveEvidence(
            named: "live-tmux-claude-ghostty",
            snapshot: snapshot,
            screen: screen,
            details: [
                "engine: ghostty", "command: \(claude), in tmux session \(tmuxSessionName) of \(sandbox.server.executablePath)",
                "tmux socket folder: \(sandbox.root.path)",
                "exit: closed the tab, ending its tmux session; session ended: \(sessionEnded), CLI \(cliProcessID) reaped: \(cliEnded), tmux client \(clientProcessID) reaped: \(clientReaped)",
            ]
        )
        #expect(sessionEnded)
        #expect(cliEnded, "Claude Code's process \(cliProcessID) still runs")
        #expect(clientReaped, "The tmux client \(clientProcessID) was not reaped")
    }

    @Test func codexRunsDirectlyInAGhosttyTab() async throws {
        let codex = try #require(LiveCLI.codex.path, "No codex found in \(LiveCLI.codex.candidatePaths)")
        let run = try LiveCLIRun(name: "local-codex-ghostty")
        let tab = TerminalSession(
            engine: .ghostty,
            conversation: nil,
            provider: .codex,
            projectPath: run.project.path,
            action: .new,
            displayTitle: "Codex",
            command: NativeCLICommand(
                executablePath: codex,
                arguments: [],
                workingDirectory: run.project.path,
                // Codex's launcher is a Node script, and finds `node` beside it.
                environment: run.cliEnvironment(executableDirectory: (codex as NSString).deletingLastPathComponent)
            )
        )
        let window = LiveCLIWindow(showing: tab.terminalView)
        defer {
            tab.close()
            window.close()
            // Also when the case fails before Codex exits; after a passing case nothing is left to end.
            _ = run.endProcessesStartedFromCodexHome()
        }

        tab.startIfNeeded()
        let processID = tab.processID
        try #require(processID > 0)
        try await run.waitForScreen(of: tab, toShow: "Codex")
        let snapshot = try #require(LiveCLISnapshot(of: tab.terminalView), "No image of the Ghostty terminal")
        let screen = LiveCLIScreen.text(of: tab)
        let exit = await LiveCLIExit.pressControlCTwice(in: tab, window: window)
        let endedDaemons = run.endProcessesStartedFromCodexHome()

        try run.saveEvidence(
            named: "live-local-codex-ghostty",
            snapshot: snapshot,
            screen: screen,
            details: [
                "engine: ghostty", "command: \(codex)", "exit: \(exit.description)",
                "background processes Codex started from this run's CODEX_HOME, ended after it exited: \(endedDaemons)",
            ]
        )
        #expect(exit.reaped, "Codex's process \(processID) was not reaped: \(exit.description)")
    }

    /// A plain terminal on the host, opened the way the app opens one: `ssh` runs a login shell in the folder. The test
    /// types a command whose output differs from what it types.
    @Test(.enabled(if: LiveCLIEvidenceSettings.sshHost != nil, "Set JUSTSESSIONS_LIVE_SSH_HOST to an SSH host to open a tab on it"))
    func anSSHTabRunsAShellOnTheHostInAGhosttyTab() async throws {
        let host = try #require(LiveCLIEvidenceSettings.sshHost)
        let run = try LiveCLIRun(name: "ssh-\(host)-ghostty")
        let shell = try await LiveSSHShell(host: host, run: run)
        defer { shell.close() }

        shell.type("printf 'JUSTSESSIONS_%s\\n' LIVE_SSH_OK; uname -a\r")
        try await run.waitForScreen(of: shell.tab, toShow: "JUSTSESSIONS_LIVE_SSH_OK")
        let snapshot = try #require(LiveCLISnapshot(of: shell.tab.terminalView), "No image of the Ghostty terminal")
        let screen = LiveCLIScreen.text(of: shell.tab)
        let reaped = await shell.closeTab()

        try run.saveEvidence(
            named: "live-ssh-shell-ghostty",
            snapshot: snapshot,
            screen: screen,
            details: ["engine: ghostty", "command: \(shell.commandLine)", "exit: closed the tab; ssh \(shell.clientProcessID) reaped: \(reaped)"]
        )
        #expect(reaped)
    }

    /// Claude Code installed on the host, started from a plain terminal on it with a settings folder of its own, so it
    /// shows its first-run screen and never reads the host's own settings. Closing the tab hangs up on it; the test then
    /// removes the folder and checks that nothing started with it still runs.
    @Test(.enabled(if: LiveCLIEvidenceSettings.sshHost != nil, "Set JUSTSESSIONS_LIVE_SSH_HOST to an SSH host to open a tab on it"))
    func claudeCodeRunsOnTheSSHHostInAGhosttyTab() async throws {
        let host = try #require(LiveCLIEvidenceSettings.sshHost)
        let run = try LiveCLIRun(name: "ssh-claude-\(host)-ghostty")
        let remoteConfiguration = "/tmp/justsessions-live-claude-\(UUID().uuidString)"
        let shell = try await LiveSSHShell(host: host, run: run)
        defer {
            shell.close()
            _ = LiveSSHShell.endProcesses(startedWith: remoteConfiguration, on: host)
        }

        shell.type("CLAUDE_CONFIG_DIR=\(remoteConfiguration) DISABLE_AUTOUPDATER=1 claude\r")
        try await run.waitForScreen(of: shell.tab, toShow: "Claude Code")
        let snapshot = try #require(LiveCLISnapshot(of: shell.tab.terminalView), "No image of the Ghostty terminal")
        let screen = LiveCLIScreen.text(of: shell.tab)
        let reaped = await shell.closeTab()
        let left = LiveSSHShell.endProcesses(startedWith: remoteConfiguration, on: host)

        try run.saveEvidence(
            named: "live-ssh-claude-ghostty",
            snapshot: snapshot,
            screen: screen,
            details: [
                "engine: ghostty", "command: \(shell.commandLine)",
                "typed: CLAUDE_CONFIG_DIR=\(remoteConfiguration) DISABLE_AUTOUPDATER=1 claude",
                "exit: closed the tab; ssh \(shell.clientProcessID) reaped: \(reaped); on the host, \(left)",
            ]
        )
        #expect(reaped)
        #expect(left == "processes still running with the folder after the tab closed: 0; folder removed")
    }
}

/// A plain terminal tab on an SSH host in a Ghostty terminal, opened through `ConversationStore` as the app opens one,
/// in an off-screen window, once its login shell's prompt shows.
@MainActor
private final class LiveSSHShell {
    let tab: TerminalSession
    private let store: ConversationStore
    private let settings: IsolatedUserDefaults
    private let window: LiveCLIWindow
    private(set) var clientProcessID: Int32 = 0

    init(host: String, run: LiveCLIRun) async throws {
        try LiveCLIRun.requireIsolatedProcessSettings()
        settings = try IsolatedUserDefaults()
        store = ConversationStore(
            adapters: [StaticConversationAdapter(discoveredConversations: [])],
            commandResolver: NativeCLICommandResolver(searchDirectories: [], inheritedEnvironment: [:], bundledTmuxDirectory: nil),
            userDefaults: settings.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            terminalEngineStore: try TerminalEngineStore.pinned(to: .ghostty),
            startsBackgroundPolling: false
        )
        store.openPlainTerminal(in: ProjectLocation(host: .ssh(host), path: "/tmp"))
        tab = try #require(store.terminalSessions.last)
        #expect(tab.engine == .ghostty)
        window = LiveCLIWindow(showing: tab.terminalView)
        tab.startIfNeeded()
        clientProcessID = tab.processID
        // The login shell's prompt, whatever it looks like.
        try await run.waitForScreen(of: tab, toShow: nil, stableFor: .seconds(2))
    }

    var commandLine: String { "\(tab.command.executablePath) \(tab.command.arguments.joined(separator: " "))" }

    func type(_ text: String) {
        LiveCLIKeys.type(text, into: tab.terminalView, window: window)
    }

    /// Closes the tab, which hangs up on `ssh`, and returns whether its process was reaped.
    func closeTab() async -> Bool {
        store.closeTerminal(tab.id)
        return await LiveCLIExit.waitUntilReaped(clientProcessID)
    }

    func close() {
        store.closeAllTerminals()
        window.close()
        settings.removeSuite()
    }

    /// Waits up to 10 seconds for the host's processes started with `folder` in their environment to end, ends any
    /// left, removes the folder, and says what it found. Reads `/proc`, so on a host without it, it only removes the
    /// folder.
    static func endProcesses(startedWith folder: String, on host: String) -> String {
        let script = """
        d='\(folder)'
        count() { grep -l -s -F -- "$d" /proc/[0-9]*/environ 2>/dev/null | wc -l | tr -d ' '; }
        if [ ! -r /proc/self/environ ]; then rm -rf "$d"; echo "no /proc to look in; folder removed"; exit 0; fi
        n=$(count); i=0
        while [ "$n" != 0 ] && [ $i -lt 10 ]; do sleep 1; i=$((i + 1)); n=$(count); done
        for p in $(grep -l -s -F -- "$d" /proc/[0-9]*/environ 2>/dev/null | cut -d/ -f3); do kill -9 "$p" 2>/dev/null; done
        rm -rf "$d"
        echo "processes still running with the folder after the tab closed: $n; folder removed"
        """
        let output = BoundedProcessRunner.output(
            ofExecutable: "/usr/bin/ssh",
            arguments: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, script],
            timeout: 40
        )
        return output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "the host didn't answer"
    }
}

/// What the tab's terminal shows. SwiftTerm leaves cells nothing was written to as NUL, where Claude Code moves the
/// cursor rather than writing spaces.
@MainActor
private enum LiveCLIScreen {
    static func text(of tab: TerminalSession) -> String {
        screenText(of: tab.terminalView).replacingOccurrences(of: "\u{0}", with: " ")
    }
}

/// Whether the suite runs, and the SSH host it opens a tab on, if any.
private enum LiveCLIEvidenceSettings {
    static var isEnabled: Bool { environment["JUSTSESSIONS_LIVE_EVIDENCE"] == "1" }
    static var sshHost: String? { environment["JUSTSESSIONS_LIVE_SSH_HOST"].flatMap { $0.isEmpty ? nil : $0 } }
    private static var environment: [String: String] { ProcessInfo.processInfo.environment }
}

/// Where a CLI is installed: an override in the environment, or else the first of the usual places.
private struct LiveCLI {
    let candidatePaths: [String]

    static let claude = LiveCLI(variable: "JUSTSESSIONS_LIVE_CLAUDE", name: "claude")
    static let codex = LiveCLI(variable: "JUSTSESSIONS_LIVE_CODEX", name: "codex")

    private init(variable: String, name: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        candidatePaths = ProcessInfo.processInfo.environment[variable].map { [$0] }
            ?? ["\(home)/.local/bin/\(name)", "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"]
    }

    var path: String? {
        candidatePaths.first(where: FileManager.default.isExecutableFile(atPath:))
    }
}

/// One case's folders: a project, a home folder, and the CLIs' settings folders, all new and all its own.
@MainActor
private struct LiveCLIRun {
    let root: URL
    let project: URL
    let home: URL
    let claudeConfiguration: URL
    let codexHome: URL

    init(name: String) throws {
        let scratch = ProcessInfo.processInfo.environment["JUSTSESSIONS_LIVE_SCRATCH_DIRECTORY"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("JustSessionsLiveEvidence")
        root = scratch.appendingPathComponent("\(name)-\(UUID().uuidString.prefix(8))")
        project = root.appendingPathComponent("project")
        home = root.appendingPathComponent("home")
        claudeConfiguration = root.appendingPathComponent("claude-config")
        codexHome = root.appendingPathComponent("codex-home")
        for folder in [project, home, claudeConfiguration, codexHome] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    /// A `ConversationStore` asks the installed `claude` for its `--help` with the test process's own environment.
    static func requireIsolatedProcessSettings(sourceLocation: SourceLocation = #_sourceLocation) throws {
        let environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for variable in ["CLAUDE_CONFIG_DIR", "CODEX_HOME"] {
            let folder = environment[variable] ?? ""
            try #require(
                !folder.isEmpty && !folder.hasPrefix(home + "/."),
                "Set \(variable) to an empty folder for the test process, so the app's own CLI checks never read your settings",
                sourceLocation: sourceLocation
            )
        }
    }

    /// Codex starts a background app server from `CODEX_HOME` that outlives the CLI. Ends those of this run, found by
    /// their executable's path, and returns their process ids.
    func endProcessesStartedFromCodexHome() -> [Int32] {
        let pathInCodexHome = "\(root.lastPathComponent)/\(codexHome.lastPathComponent)/"
        let output = BoundedProcessRunner.output(ofExecutable: "/usr/bin/pgrep", arguments: ["-f", pathInCodexHome], timeout: 5) ?? ""
        let processIDs = output.split(whereSeparator: \.isNewline).compactMap { Int32($0) }.filter { $0 > 0 }
        for processID in processIDs { kill(processID, SIGTERM) }
        // One that is still running two seconds later is killed.
        let deadline = Date.now.addingTimeInterval(2)
        while Date.now < deadline, processIDs.contains(where: { kill($0, 0) == 0 }) { usleep(50_000) }
        for processID in processIDs where kill(processID, 0) == 0 { kill(processID, SIGKILL) }
        return processIDs
    }

    /// Points both CLIs at this run's settings folders, and keeps Claude Code from updating itself.
    var cliSettingsEnvironment: [String: String] {
        ["CLAUDE_CONFIG_DIR": claudeConfiguration.path, "CODEX_HOME": codexHome.path, "DISABLE_AUTOUPDATER": "1"]
    }

    /// What a CLI run directly in a tab gets: this run's home and settings folders, and the system's tools.
    func cliEnvironment(executableDirectory: String) -> [String] {
        let environment = cliSettingsEnvironment.merging([
            "HOME": home.path,
            "PATH": "\(executableDirectory):/usr/bin:/bin:/usr/sbin:/sbin",
            "TERM": "xterm-256color",
            "COLORTERM": "truecolor",
            "LANG": "en_US.UTF-8",
        ]) { $1 }
        return environment.map { "\($0.key)=\($0.value)" }.sorted()
    }

    /// Waits until the tab's screen shows `marker`, or anything when it is nil, and stays the same for `stableFor`, so
    /// the snapshot catches a finished screen; fails after a minute with what the screen showed.
    func waitForScreen(
        of tab: TerminalSession,
        toShow marker: String?,
        stableFor: Duration = .milliseconds(1500),
        diagnostics: () -> String = { "" },
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + LiveCLIEvidence.screenTimeout
        var lastScreen = ""
        var unchangedSince = clock.now
        while clock.now < deadline {
            let screen = LiveCLIScreen.text(of: tab)
            if screen != lastScreen {
                lastScreen = screen
                unchangedSince = clock.now
            } else if marker.map(screen.contains) ?? true, !screen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      clock.now - unchangedSince >= stableFor {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let message = "The screen never showed \"\(marker ?? "anything")\" within \(LiveCLIEvidence.screenTimeout). "
            + "exited: \(tab.hasExited), exit code: \(String(describing: tab.exitCode)). \(diagnostics())\nScreen:\n\(lastScreen)"
        Issue.record(Comment(rawValue: message), sourceLocation: sourceLocation)
        throw LiveCLIEvidenceError.screenTimedOut
    }

    func saveEvidence(named name: String, snapshot: LiveCLISnapshot, screen: String, details: [String]) throws {
        let directory = ProcessInfo.processInfo.environment["JUSTSESSIONS_LIVE_EVIDENCE_DIRECTORY"].map { URL(fileURLWithPath: $0) }
            ?? root.deletingLastPathComponent().appendingPathComponent("evidence")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try snapshot.pngData.write(to: directory.appendingPathComponent("\(name).png"))
        let header = (details + [
            "project: \(project.path)",
            "captured: \(ISO8601DateFormatter().string(from: .now))",
            "image: \(snapshot.source)",
        ]).map { "# \($0)" }
        try (header.joined(separator: "\n") + "\n\n" + screen + "\n").write(
            to: directory.appendingPathComponent("\(name).txt"), atomically: true, encoding: .utf8
        )
    }
}

private enum LiveCLIEvidenceError: Error {
    case screenTimedOut
}

/// A window for the tab's terminal, which a Ghostty terminal needs to lay out and draw. It is ordered front far off
/// screen, so it draws without showing.
@MainActor
private final class LiveCLIWindow {
    let window: NSWindow

    init(showing terminalView: any TabTerminalView) {
        _ = NSApplication.shared
        window = NSWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: 1000, height: 640),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = terminalView
        window.orderFrontRegardless()
        window.makeFirstResponder(terminalView)
    }

    var windowNumber: Int { window.windowNumber }

    func close() {
        window.contentView = nil
        window.close()
    }
}

/// An image of the terminal. SwiftTerm draws in `draw(_:)`, so `cacheDisplay` captures it. Ghostty's
/// `snapshotImage()` uses `cacheDisplay` too, which may miss what Metal drew; then the image is read from the
/// IOSurface Ghostty presents in the view's layer.
@MainActor
private struct LiveCLISnapshot {
    let pngData: Data
    /// How the image was made.
    let source: String

    init?(of terminalView: any TabTerminalView) {
        if let ghosttyView = terminalView as? GhosttyTabTerminalView {
            if let image = ghosttyView.snapshotImage(), let bitmap = Self.bitmap(of: image), Self.showsSomething(bitmap),
               let png = bitmap.representation(using: .png, properties: [:]) {
                pngData = png
                source = "GhosttyTabTerminalView.snapshotImage()"
                return
            }
            guard let bitmap = Self.bitmapOfPresentedSurface(in: ghosttyView), Self.showsSomething(bitmap),
                  let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
            pngData = png
            source = "the IOSurface in the Ghostty view's layer; snapshotImage() was blank"
            return
        }
        guard let bitmap = terminalView.bitmapImageRepForCachingDisplay(in: terminalView.bounds) else { return nil }
        terminalView.cacheDisplay(in: terminalView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        pngData = png
        source = "bitmapImageRepForCachingDisplay + cacheDisplay"
    }

    private static func bitmap(of image: NSImage) -> NSBitmapImageRep? {
        image.representations.compactMap { $0 as? NSBitmapImageRep }.first
            ?? image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
    }

    private static func bitmapOfPresentedSurface(in view: NSView) -> NSBitmapImageRep? {
        guard let contents = view.layer?.contents, CFGetTypeID(contents as CFTypeRef) == IOSurfaceGetTypeID() else { return nil }
        let surface = unsafeBitCast(contents as AnyObject, to: IOSurfaceRef.self)
        let image = CIImage(ioSurface: surface)
        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else { return nil }
        return NSBitmapImageRep(cgImage: cgImage)
    }

    /// More than one color anywhere in the image: a blank or all-black capture has one. A shell's few short lines
    /// cover little of the terminal, so every pixel is looked at, until a second color turns up.
    private static func showsSomething(_ bitmap: NSBitmapImageRep) -> Bool {
        var firstPixel: [Int]?
        var pixel = [Int](repeating: 0, count: max(bitmap.samplesPerPixel, 1))
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                bitmap.getPixel(&pixel, atX: x, y: y)
                guard let firstPixel else {
                    firstPixel = pixel
                    continue
                }
                if pixel != firstPixel { return true }
            }
        }
        return false
    }
}

/// Keys pressed in the terminal, through the engine's own `keyDown`, as a US keyboard sends them.
@MainActor
private enum LiveCLIKeys {
    static func pressControlC(in terminalView: NSView, window: LiveCLIWindow) {
        terminalView.keyDown(with: event(keyCode: 8, characters: "\u{3}", ignoringModifiers: "c", modifiers: .control, window: window))
    }

    /// Printable ASCII and Return only.
    static func type(_ text: String, into terminalView: NSView, window: LiveCLIWindow) {
        for character in text {
            let characters = String(character)
            let keyCode = character == "\r" ? 36 : 0
            terminalView.keyDown(with: event(keyCode: keyCode, characters: characters, ignoringModifiers: characters, modifiers: [], window: window))
        }
    }

    private static func event(
        keyCode: Int,
        characters: String,
        ignoringModifiers: String,
        modifiers: NSEvent.ModifierFlags,
        window: LiveCLIWindow
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: ignoringModifiers,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )!
    }
}

/// How a CLI's tab ended, and whether its process was reaped.
@MainActor
private struct LiveCLIExit {
    let description: String
    let reaped: Bool

    /// Ctrl-C twice, as you quit Claude Code or Codex; closing the tab if the CLI still runs after that.
    static func pressControlCTwice(in tab: TerminalSession, window: LiveCLIWindow) async -> LiveCLIExit {
        let processID = tab.processID
        let screenBefore = LiveCLIScreen.text(of: tab)
        for _ in 0..<2 {
            LiveCLIKeys.pressControlC(in: tab.terminalView, window: window)
            try? await Task.sleep(for: .milliseconds(400))
        }
        let exitedOnItsOwn = await waitUntil(timeout: .seconds(15)) { tab.hasExited }
        let screenChanged = LiveCLIScreen.text(of: tab) != screenBefore
        if !exitedOnItsOwn { tab.close() }
        let reaped = await waitUntilReaped(processID)
        let how = exitedOnItsOwn
            ? "Ctrl-C twice; the CLI exited with code \(tab.exitCode.map(String.init) ?? "unknown")"
            : "Ctrl-C twice did not end the CLI within 15 s (the screen \(screenChanged ? "changed" : "did not change")), so the tab was closed"
        return LiveCLIExit(description: "\(how); process \(processID) reaped: \(reaped)", reaped: reaped)
    }

    /// `kill(pid, 0)` still succeeds for a zombie, so it fails only once the process has ended and been reaped.
    static func waitUntilReaped(_ processID: Int32) async -> Bool {
        guard processID > 0 else { return false }
        return await waitUntil(timeout: .seconds(15)) { kill(processID, 0) != 0 }
    }

    private static func waitUntil(timeout: Duration, _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }
}
