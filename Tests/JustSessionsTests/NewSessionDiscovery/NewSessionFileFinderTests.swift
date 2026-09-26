import Darwin
import Foundation
import Testing
@testable import JustSessions

struct NewSessionFileFinderTests {
    /// Larger than any macOS process id, so it stands for a wrapper process that no longer matters.
    private static let wrapperProcessID: Int32 = 999_999

    @Test func findsThePreassignedClaudeTranscriptEvenAfterTheCLIExited() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = UUID().uuidString.lowercased()
        try writeClaudeTranscript(sessionID: sessionID, under: root)
        let tab = claudeTab(processID: 0, preassignedSessionID: sessionID, isRunning: false)

        let sessionFiles = finder(claudeConfigurationDirectory: root)
            .sessionFiles(for: [tab], processTree: ProcessTree(parentProcessIDs: [:]))

        #expect(sessionFiles[tab.terminalID]?.sessionID == sessionID)
        #expect(sessionFiles[tab.terminalID]?.file.lastPathComponent == "\(sessionID).jsonl")
    }

    @Test func findsAWrappedClaudeCLIThroughTheRegistryOfItsChildProcess() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = UUID().uuidString.lowercased()
        let cliProcessID: Int32 = 4_242
        try writeClaudeTranscript(sessionID: sessionID, under: root)
        let sessions = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try #"{"sessionId":"\#(sessionID)"}"#.write(
            to: sessions.appendingPathComponent("\(cliProcessID).json"),
            atomically: true,
            encoding: .utf8
        )
        let tab = claudeTab(processID: Self.wrapperProcessID, preassignedSessionID: nil, isRunning: true)
        let processTree = ProcessTree(parentProcessIDs: [cliProcessID: Self.wrapperProcessID])

        let sessionFiles = finder(claudeConfigurationDirectory: root).sessionFiles(for: [tab], processTree: processTree)

        #expect(sessionFiles[tab.terminalID]?.sessionID == sessionID)
        #expect(finder(claudeConfigurationDirectory: root)
            .sessionFiles(for: [tab], processTree: ProcessTree(parentProcessIDs: [:])).isEmpty)
    }

    @Test func findsTheRolloutThatTheChildOfAWrapperScriptHoldsOpen() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = UUID().uuidString.lowercased()
        let dayDirectory = root.appendingPathComponent("sessions/2026/09/25")
        try FileManager.default.createDirectory(at: dayDirectory, withIntermediateDirectories: true)
        let rollout = dayDirectory.appendingPathComponent("rollout-2026-09-25T00-00-00-\(sessionID).jsonl")
        try "{}\n".write(to: rollout, atomically: true, encoding: .utf8)
        // The wrapper never opens the rollout; only the child it starts, standing in for the real CLI, does.
        let wrapper = Process()
        wrapper.executableURL = URL(fileURLWithPath: "/bin/sh")
        wrapper.arguments = ["-c", #"sleep 30 3<"$0" & echo $!; wait"#, rollout.path]
        let output = Pipe()
        wrapper.standardOutput = output
        try wrapper.run()
        let childLine = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self)
        let childProcessID = try #require(Int32(childLine.trimmingCharacters(in: .whitespacesAndNewlines)))
        defer {
            kill(childProcessID, SIGKILL)
            wrapper.waitUntilExit()
        }
        let tab = WaitingNewSessionTab(
            terminalID: UUID(),
            provider: .codex,
            processID: wrapper.processIdentifier,
            preassignedSessionID: nil,
            branchedFromSessionID: nil,
            isRunning: true
        )
        let finder = finder(claudeConfigurationDirectory: root)

        // The child opens the file right after it starts, so give it a moment.
        var sessionFile: NewSessionFile?
        for _ in 0..<40 where sessionFile == nil {
            sessionFile = finder.sessionFiles(for: [tab], processTree: .ofRunningProcesses())[tab.terminalID]
            if sessionFile == nil { try await Task.sleep(for: .milliseconds(50)) }
        }

        #expect(sessionFile?.sessionID == sessionID)
        #expect(sessionFile?.file.lastPathComponent == rollout.lastPathComponent)
        #expect(finder.sessionFiles(for: [tab], processTree: ProcessTree(parentProcessIDs: [:])).isEmpty)
    }

    @Test func branchTabSkipsTheSessionItForkedInClaudesRegistry() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let forkedSessionID = UUID().uuidString.lowercased()
        let forkSessionID = UUID().uuidString.lowercased()
        let cliProcessID: Int32 = 4_243
        try writeClaudeTranscript(sessionID: forkedSessionID, under: root)
        try writeClaudeTranscript(sessionID: forkSessionID, under: root)
        let tab = branchTab(provider: .claude, processID: cliProcessID, branchedFromSessionID: forkedSessionID)
        let finder = finder(claudeConfigurationDirectory: root)
        let processTree = ProcessTree(parentProcessIDs: [:])

        try writeClaudeRegistryRecord(sessionID: forkedSessionID, processID: cliProcessID, under: root)
        #expect(finder.sessionFiles(for: [tab], processTree: processTree).isEmpty)

        try writeClaudeRegistryRecord(sessionID: forkSessionID, processID: cliProcessID, under: root)
        #expect(finder.sessionFiles(for: [tab], processTree: processTree)[tab.terminalID]?.sessionID == forkSessionID)
    }

    @Test func branchTabTakesItsForkRolloutWhileTheForkedOneIsAlsoOpen() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let forkedSessionID = UUID().uuidString.lowercased()
        let forkSessionID = UUID().uuidString.lowercased()
        let forkedRollout = try writeCodexRollout(sessionID: forkedSessionID, under: root)
        let forkRollout = try writeCodexRollout(sessionID: forkSessionID, under: root)
        // Stands in for `codex fork`, holding the rollout it forked open ahead of its own.
        let cli = Process()
        cli.executableURL = URL(fileURLWithPath: "/bin/sh")
        cli.arguments = ["-c", #"exec sleep 30 3<"$0" 4<"$1""#, forkedRollout.path, forkRollout.path]
        try cli.run()
        defer {
            cli.terminate()
            cli.waitUntilExit()
        }
        let tab = branchTab(provider: .codex, processID: cli.processIdentifier, branchedFromSessionID: forkedSessionID)
        let finder = finder(claudeConfigurationDirectory: root)

        // The shell opens both files and then becomes `sleep`, so give it a moment.
        var sessionFile: NewSessionFile?
        for _ in 0..<40 where sessionFile == nil {
            sessionFile = finder.sessionFiles(for: [tab], processTree: ProcessTree(parentProcessIDs: [:]))[tab.terminalID]
            if sessionFile == nil { try await Task.sleep(for: .milliseconds(50)) }
        }

        #expect(sessionFile?.sessionID == forkSessionID)
        #expect(sessionFile?.file.lastPathComponent == forkRollout.lastPathComponent)
    }

    @Test func findsNothingBeforeTheCLIWritesItsSession() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        // A process of its own: tests running in parallel may hold session files open in this one.
        let idleCLI = Process()
        idleCLI.executableURL = URL(fileURLWithPath: "/bin/sleep")
        idleCLI.arguments = ["30"]
        try idleCLI.run()
        defer {
            idleCLI.terminate()
            idleCLI.waitUntilExit()
        }
        let claude = claudeTab(
            processID: idleCLI.processIdentifier,
            preassignedSessionID: UUID().uuidString.lowercased(),
            isRunning: true
        )
        let codex = WaitingNewSessionTab(
            terminalID: UUID(),
            provider: .codex,
            processID: idleCLI.processIdentifier,
            preassignedSessionID: nil,
            branchedFromSessionID: nil,
            isRunning: true
        )

        let sessionFiles = finder(claudeConfigurationDirectory: root)
            .sessionFiles(for: [claude, codex], processTree: ProcessTree(parentProcessIDs: [:]))

        #expect(sessionFiles.isEmpty)
    }

    private func finder(claudeConfigurationDirectory: URL) -> NewSessionFileFinder {
        NewSessionFileFinder(
            claudeTranscripts: ClaudeSessionFileLocator(configurationDirectory: claudeConfigurationDirectory),
            claudeRegistry: ClaudeLiveSessionRegistry(configurationDirectory: claudeConfigurationDirectory)
        )
    }

    private func claudeTab(processID: Int32, preassignedSessionID: String?, isRunning: Bool) -> WaitingNewSessionTab {
        WaitingNewSessionTab(
            terminalID: UUID(),
            provider: .claude,
            processID: processID,
            preassignedSessionID: preassignedSessionID,
            branchedFromSessionID: nil,
            isRunning: isRunning
        )
    }

    private func branchTab(
        provider: ConversationProvider,
        processID: Int32,
        branchedFromSessionID: String
    ) -> WaitingNewSessionTab {
        WaitingNewSessionTab(
            terminalID: UUID(),
            provider: provider,
            processID: processID,
            preassignedSessionID: nil,
            branchedFromSessionID: branchedFromSessionID,
            isRunning: true
        )
    }

    private func writeClaudeTranscript(sessionID: String, under root: URL) throws {
        let project = root.appendingPathComponent("projects/-tmp-new-session-project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "{}\n".write(to: project.appendingPathComponent("\(sessionID).jsonl"), atomically: true, encoding: .utf8)
    }

    private func writeClaudeRegistryRecord(sessionID: String, processID: Int32, under root: URL) throws {
        let sessions = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try #"{"sessionId":"\#(sessionID)"}"#.write(
            to: sessions.appendingPathComponent("\(processID).json"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func writeCodexRollout(sessionID: String, under root: URL) throws -> URL {
        let dayDirectory = root.appendingPathComponent("sessions/2026/09/25")
        try FileManager.default.createDirectory(at: dayDirectory, withIntermediateDirectories: true)
        let rollout = dayDirectory.appendingPathComponent("rollout-2026-09-25T00-00-00-\(sessionID).jsonl")
        try "{}\n".write(to: rollout, atomically: true, encoding: .utf8)
        return rollout
    }
}
