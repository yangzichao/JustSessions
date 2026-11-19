import Darwin
import Foundation
import Testing

@testable import JustSessions

/// What a Kiro CLI does, as its turn markers say; see `KiroTurnMarkers`. The markers are as Kiro CLI 2.31.1 keeps them
/// on Linux: `<pid of its TUI>-<turn start in ms>.json`, there only while a turn runs.
struct KiroTurnMarkersTests {
    @Test func readsTheProcessFromAMarkersName() {
        #expect(KiroTurnMarkers.processID(inMarkerName: "1416-1792101078428.json") == 1416)
        #expect(KiroTurnMarkers.processID(inMarkerName: "1416-1792101078428.json.tmp") == nil)
        #expect(KiroTurnMarkers.processID(inMarkerName: "notes.json") == nil)
        #expect(KiroTurnMarkers.processID(inMarkerName: "x-1.json") == nil)
    }

    @Test func aMissingFolderTellsNothingAndAnEmptyOneNoTurn() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let markers = KiroTurnMarkers(directory: directory.appendingPathComponent("turn-markers"))
        #expect(markers.processIDsWithATurn() == nil)

        try FileManager.default.createDirectory(at: markers.directory, withIntermediateDirectories: true)
        #expect(markers.processIDsWithATurn() == [])
        try Self.writeMarker(forProcess: 1416, in: markers.directory)
        try Self.writeMarker(forProcess: 2015, in: markers.directory)
        #expect(markers.processIDsWithATurn() == [1416, 2015])
    }

    @Test func readsTheNamesTheRelayKeeps() {
        #expect(KiroTurnMarkers.activity(named: "working") == .working)
        #expect(KiroTurnMarkers.activity(named: "idle") == .idle)
        #expect(KiroTurnMarkers.activity(named: "busy") == nil)
        let prefix = RemoteCLIActivityTitle.titlePrefix
        #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: prefix + "working:", of: .kiro) == .working)
        #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: prefix + "idle:", of: .kiro) == .idle)
        #expect(RemoteCLIActivityTitle.providers.contains(.kiro))
    }

    /// A marker names Kiro's TUI, below the `kiro-cli` the tab started; here a shell and its `sleep` stand in.
    @Test func aTabsKiroWorksWhileAProcessBelowItHasATurn() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let markers = KiroTurnMarkers(directory: directory.appendingPathComponent("turn-markers"))
        let cli = Process()
        cli.executableURL = URL(fileURLWithPath: "/bin/sh")
        cli.arguments = ["-c", "sleep 600 & wait"]
        try cli.run()
        defer {
            if cli.isRunning {
                kill(-cli.processIdentifier, SIGTERM)
                cli.terminate()
            }
        }
        let tui = try #require(Self.waitForChild(of: cli.processIdentifier))
        defer { kill(tui, SIGTERM) }
        let reader = CLIActivityReader(
            claudeRegistry: ClaudeLiveSessionRegistry(configurationDirectory: directory),
            codexTurnTracker: CodexRolloutTurnTracker(),
            liveSessionReporting: nil,
            kiroTurnMarkers: markers
        )
        func activity() -> CLIActivity? {
            reader.activities(for: [CLIActivityProbe(provider: .kiro, processID: cli.processIdentifier, sessionFile: nil)]).first ?? nil
        }

        // A Kiro too old to keep the folder tells nothing.
        #expect(activity() == nil)
        try FileManager.default.createDirectory(at: markers.directory, withIntermediateDirectories: true)
        #expect(activity() == .idle)
        // Another Kiro's turn, as in another tab, is not this one's.
        try Self.writeMarker(forProcess: getpid(), in: markers.directory)
        #expect(activity() == .idle)
        try Self.writeMarker(forProcess: tui, in: markers.directory)
        #expect(activity() == .working)
        // The turn ended, or Ctrl-C or Esc cancelled it.
        try FileManager.default.removeItem(at: markers.directory.appendingPathComponent("\(tui)-1792101078428.json"))
        #expect(activity() == .idle)
    }

    private static func writeMarker(forProcess processID: Int32, in directory: URL) throws {
        let marker = #"{"pid":\#(processID),"engine":"v2","session_interface":"interactive_cli","turn_started_at_ms":1792101078428}"#
        try marker.write(to: directory.appendingPathComponent("\(processID)-1792101078428.json"), atomically: true, encoding: .utf8)
    }

    private static func waitForChild(of processID: Int32) -> Int32? {
        let deadline = Date(timeIntervalSinceNow: 120)
        while Date() < deadline {
            if let child = ProcessTree.ofRunningProcesses().processIDs(rootedAt: processID).dropFirst().first { return child }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return nil
    }
}
