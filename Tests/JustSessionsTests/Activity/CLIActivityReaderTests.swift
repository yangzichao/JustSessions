import Darwin
import Foundation
import Testing
@testable import JustSessions

struct CLIActivityReaderTests {
    @Test func aCodexTurnLeftOpenByAnEarlierCLIIsNoWork() {
        let cliStartedAt = Date(timeIntervalSince1970: 1_790_000_000)

        #expect(CLIActivityReader.codexActivity(turnState: nil, cliStartedAt: cliStartedAt) == nil)
        #expect(CLIActivityReader.codexActivity(turnState: .betweenTurns, cliStartedAt: cliStartedAt) == .idle)
        #expect(CLIActivityReader.codexActivity(turnState: .inTurn(startedAt: cliStartedAt + 5), cliStartedAt: cliStartedAt) == .working)
        // An earlier CLI ended in the middle of this turn.
        #expect(CLIActivityReader.codexActivity(turnState: .inTurn(startedAt: cliStartedAt - 5), cliStartedAt: cliStartedAt) == .idle)
        // Without both times, a turn under way is taken at its word.
        #expect(CLIActivityReader.codexActivity(turnState: .inTurn(startedAt: nil), cliStartedAt: cliStartedAt) == .working)
        #expect(CLIActivityReader.codexActivity(turnState: .inTurn(startedAt: cliStartedAt - 5), cliStartedAt: nil) == .working)
    }

    @Test func readsEachProbedCLI() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sessionsDirectory = directory.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try #"{"sessionId":"70b71200-8814-4822-a2e5-24abf31f7cbd","status":"busy"}"#
            .write(to: sessionsDirectory.appendingPathComponent("4242.json"), atomically: true, encoding: .utf8)
        // This test's own process stands in for the Codex CLI.
        let cliProcessID = getpid()
        let cliStartedAt = try #require(RunningProcessInfo.startDate(of: cliProcessID))
        let currentTurnFile = directory.appendingPathComponent("current.jsonl")
        try CodexRolloutLines.write([CodexRolloutLines.turnStarted(at: cliStartedAt + 1)], to: currentTurnFile)
        let leftOpenTurnFile = directory.appendingPathComponent("left-open.jsonl")
        try CodexRolloutLines.write([CodexRolloutLines.turnStarted(at: cliStartedAt - 60)], to: leftOpenTurnFile)
        let reporting = LiveSessionReporting(directory: directory.appendingPathComponent("LiveSessionReporting"))
        try FileManager.default.createDirectory(at: reporting.reportsDirectory, withIntermediateDirectories: true)
        try #"{"pid":5151,"sessionId":"01a10925-abd5-7606-8b40-1c56e397895e","activity":"waiting","waitingFor":"Allow rm?"}"#
            .write(to: reporting.reportsDirectory.appendingPathComponent("5151.json"), atomically: true, encoding: .utf8)
        try #"{"pid":5252,"sessionId":"ses_2f3b1c4d5e6f7a8b9c0d1e2f3a","activity":"idle"}"#
            .write(to: reporting.reportsDirectory.appendingPathComponent("5252.json"), atomically: true, encoding: .utf8)
        let reader = CLIActivityReader(
            claudeRegistry: ClaudeLiveSessionRegistry(configurationDirectory: directory),
            codexTurnTracker: CodexRolloutTurnTracker(),
            liveSessionReporting: reporting
        )

        let activities = reader.activities(for: [
            CLIActivityProbe(provider: .claude, processID: 4242, sessionFile: nil),
            CLIActivityProbe(provider: .claude, processID: 0, sessionFile: nil),
            CLIActivityProbe(provider: .codex, processID: cliProcessID, sessionFile: currentTurnFile),
            CLIActivityProbe(provider: .codex, processID: cliProcessID, sessionFile: leftOpenTurnFile),
            CLIActivityProbe(provider: .codex, processID: cliProcessID, sessionFile: nil),
            CLIActivityProbe(provider: .pi, processID: 5151, sessionFile: nil),
            CLIActivityProbe(provider: .opencode, processID: 5252, sessionFile: nil),
            CLIActivityProbe(provider: .pi, processID: 5353, sessionFile: nil),
            CLIActivityProbe(provider: .antigravity, processID: cliProcessID, sessionFile: nil),
        ])

        #expect(activities == [.working, nil, .working, .idle, nil, .needsInput(reason: "Allow rm?"), .idle, nil, nil])
    }

    @Test func piAndOpenCodeTellNothingWithoutTheAppsExtension() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reader = CLIActivityReader(
            claudeRegistry: ClaudeLiveSessionRegistry(configurationDirectory: directory),
            codexTurnTracker: CodexRolloutTurnTracker(),
            liveSessionReporting: nil
        )

        let activities = reader.activities(for: [
            CLIActivityProbe(provider: .pi, processID: getpid(), sessionFile: nil),
            CLIActivityProbe(provider: .opencode, processID: getpid(), sessionFile: nil),
        ])

        #expect(activities == [nil, nil])
    }
}
