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
        #expect(CLIActivityReader.codexActivity(turnState: .inTurn(startedAt: cliStartedAt - 5), cliStartedAt: cliStartedAt) == .idle)
        #expect(CLIActivityReader.codexActivity(turnState: .inTurn(startedAt: nil), cliStartedAt: cliStartedAt) == .working)
        #expect(CLIActivityReader.codexActivity(turnState: .inTurn(startedAt: cliStartedAt - 5), cliStartedAt: nil) == .working)
    }

    @Test func aCodexTurnWaitsOnYouOnlyWhileItIsThisCLIsTurn() {
        let cliStartedAt = Date(timeIntervalSince1970: 1_790_000_000)
        func activity(_ turnState: CodexTurnState?) -> CLIActivity? {
            CLIActivityReader.codexActivity(turnState: turnState, cliStartedAt: cliStartedAt, isWaitingOnYou: true)
        }

        #expect(activity(.inTurn(startedAt: cliStartedAt + 5)) == .needsInput(reason: nil))
        #expect(activity(.inTurn(startedAt: cliStartedAt - 5)) == .idle)
        #expect(activity(.betweenTurns) == .idle)
        #expect(activity(nil) == nil)
    }

    @Test func readsCodexWaitsFromItsBackgroundServer() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cx-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = try FakeCodexAppServer(
            socketPath: directory.appendingPathComponent("server.sock").path,
            linkedFrom: directory.appendingPathComponent(".codex")
        )
        defer { server.stop() }
        let cliProcessID = getpid()
        let cliStartedAt = try #require(RunningProcessInfo.startDate(of: cliProcessID))
        let inTurnFile = directory.appendingPathComponent("in-turn.jsonl")
        try CodexRolloutLines.write([CodexRolloutLines.turnStarted(at: cliStartedAt + 1)], to: inTurnFile)
        let finishedFile = directory.appendingPathComponent("finished.jsonl")
        try CodexRolloutLines.write(
            [CodexRolloutLines.turnStarted(at: cliStartedAt + 1), CodexRolloutLines.turnCompleted()], to: finishedFile)
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: "waiting")
        server.setStatus(FakeCodexAppServer.working, ofThread: "working")
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: "ended")
        let reader = CLIActivityReader(
            claudeRegistry: ClaudeLiveSessionRegistry(configurationDirectory: directory),
            codexTurnTracker: CodexRolloutTurnTracker(),
            liveSessionReporting: nil,
            codexWaitReader: CodexAppServerWaitReader(codexDirectory: directory.appendingPathComponent(".codex"), clientVersion: "test")
        )

        let activities = reader.activities(for: [
            CLIActivityProbe(provider: .codex, processID: cliProcessID, sessionFile: inTurnFile, sessionID: "waiting"),
            CLIActivityProbe(provider: .codex, processID: cliProcessID, sessionFile: inTurnFile, sessionID: "working"),
            CLIActivityProbe(provider: .codex, processID: cliProcessID, sessionFile: inTurnFile, sessionID: "not loaded"),
            CLIActivityProbe(provider: .codex, processID: cliProcessID, sessionFile: inTurnFile),
            CLIActivityProbe(provider: .codex, processID: cliProcessID, sessionFile: finishedFile, sessionID: "ended"),
        ])

        #expect(activities == [.needsInput(reason: nil), .working, .working, .working, .idle])
        #expect(server.methods.filter { $0 == "thread/read" }.count == 3)
    }

    @Test func anAntigravityTurnWaitsOnYouWhileAStepAwaitsApproval() {
        let cliStartedAt = Date(timeIntervalSince1970: 1_790_000_000)
        func activity(_ turnState: AntigravityTurnState?) -> CLIActivity? {
            CLIActivityReader.antigravityActivity(turnState: turnState, cliStartedAt: cliStartedAt)
        }

        #expect(activity(nil) == nil)
        #expect(activity(.betweenTurns) == .idle)
        #expect(activity(.inTurn(startedAt: cliStartedAt + 5, isWaitingForApproval: false)) == .working)
        #expect(activity(.inTurn(startedAt: cliStartedAt + 5, isWaitingForApproval: true)) == .needsInput(reason: nil))
        #expect(activity(.inTurn(startedAt: cliStartedAt - 5, isWaitingForApproval: true)) == .idle)
        #expect(activity(.inTurn(startedAt: nil, isWaitingForApproval: false)) == .working)
    }

    @Test func readsEachProbedCLI() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sessionsDirectory = directory.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try #"{"sessionId":"70b71200-8814-4822-a2e5-24abf31f7cbd","status":"busy"}"#
            .write(to: sessionsDirectory.appendingPathComponent("4242.json"), atomically: true, encoding: .utf8)
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
        let antigravityDirectory = directory.appendingPathComponent("antigravity-cli")
        let waitingConversation = try AntigravitySessionFixture(configurationDirectory: antigravityDirectory)
        try AntigravitySessionFixture.execute(["DELETE FROM steps"], at: waitingConversation.databaseFile)
        try waitingConversation.appendPrompt("Run date", index: 0, createdAt: cliStartedAt + 1)
        try waitingConversation.appendStep(type: 132, index: 1, status: 9, createdAt: cliStartedAt + 2)
        let leftOpenConversation = try AntigravitySessionFixture(configurationDirectory: antigravityDirectory)
        try AntigravitySessionFixture.execute(["DELETE FROM steps"], at: leftOpenConversation.databaseFile)
        try leftOpenConversation.appendPrompt("Fix the build", index: 0, createdAt: cliStartedAt - 60)
        let reader = CLIActivityReader(
            claudeRegistry: ClaudeLiveSessionRegistry(configurationDirectory: directory),
            codexTurnTracker: CodexRolloutTurnTracker(),
            liveSessionReporting: reporting,
            // Not this Mac's: a Kiro CLI from 2.31 on keeps the folder there, and its markers would answer for the probe.
            kiroTurnMarkers: KiroTurnMarkers(directory: directory.appendingPathComponent("kiro-cli/run/turn-markers"))
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
            CLIActivityProbe(provider: .antigravity, processID: cliProcessID, sessionFile: waitingConversation.databaseFile),
            CLIActivityProbe(provider: .antigravity, processID: cliProcessID, sessionFile: leftOpenConversation.databaseFile),
            CLIActivityProbe(provider: .kiro, processID: cliProcessID, sessionFile: nil),
        ])

        #expect(
            activities == [
                .working, nil, .working, .idle, nil, .needsInput(reason: "Allow rm?"), .idle, nil,
                nil, .needsInput(reason: nil), .idle, nil,
            ])
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
