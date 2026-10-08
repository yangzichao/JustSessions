import Foundation
@testable import JustSessions

/// Stands in for an Antigravity, Pi, or OpenCode CLI: it writes what the app's `LiveSessionSource` for the tool reads,
/// in the scenario's temporary folder.
protocol ScenarioCLI {
    var source: any LiveSessionSource { get }
    /// The CLI is in the session now, as with `/new`, `/clear`, `/resume`, or a new session's first prompt.
    func moves(toSession sessionID: String) throws
    /// The tool saves the session where a refresh would find it.
    func saves(session sessionID: String, projectPath: String) throws
}

/// Antigravity names the conversation it streams in its log; see `AntigravityCLILog`.
struct ScenarioAntigravityCLI: ScenarioCLI {
    let configurationDirectory: URL
    let source: any LiveSessionSource

    init(temporaryDirectory: URL) throws {
        configurationDirectory = temporaryDirectory.appendingPathComponent("antigravity-cli")
        let logFile = configurationDirectory.appendingPathComponent("log/cli-20261004_155442.log")
        try FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "I1004 15:54:42.450497      69 server.go:1612] Starting language server process\n"
            .write(to: logFile, atomically: true, encoding: .utf8)
        source = AntigravityLiveConversationSource(configurationDirectory: configurationDirectory) { _ in logFile }
    }

    func moves(toSession sessionID: String) throws {
        let logFile = configurationDirectory.appendingPathComponent("log/cli-20261004_155442.log")
        let handle = try FileHandle(forWritingTo: logFile)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(
            "I1004 15:55:37.839493    1237 server.go:1272] Starting conversation update stream for \(sessionID)\n".utf8
        ))
    }

    func saves(session sessionID: String, projectPath: String) throws {
        _ = try AntigravitySessionFixture(configurationDirectory: configurationDirectory, sessionID: sessionID, projectPath: projectPath)
    }
}

/// Pi reports its session through the app's extension, with the file it saves the session in after the first prompt.
struct ScenarioPiCLI: ScenarioCLI {
    let reporting: LiveSessionReporting
    let processID: Int32
    let sessionsDirectory: URL
    var source: any LiveSessionSource { PiLiveSessionSource(reporting: reporting) }

    func moves(toSession sessionID: String) throws {
        let report = #"{"pid":\#(processID),"sessionId":"\#(sessionID)","sessionFile":"\#(sessionFile(of: sessionID).path)"}"#
        try ScenarioReport.write(report, for: processID, in: reporting)
    }

    func saves(session sessionID: String, projectPath: String) throws {
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try #"{"type":"session","id":"\#(sessionID)","cwd":"\#(projectPath)"}"#.appending("\n")
            .write(to: sessionFile(of: sessionID), atomically: true, encoding: .utf8)
    }

    private func sessionFile(of sessionID: String) -> URL {
        sessionsDirectory.appendingPathComponent("2026-10-04T23-00-26-198Z_\(sessionID).jsonl")
    }
}

/// OpenCode reports the session it shows through the app's plugin, and none on its home screen.
struct ScenarioOpenCodeCLI: ScenarioCLI {
    let reporting: LiveSessionReporting
    let processID: Int32
    let database: OpenCodeDatabaseFixture
    var source: any LiveSessionSource { OpenCodeLiveSessionSource(reporting: reporting, databaseFile: database.file) }

    func moves(toSession sessionID: String) throws {
        try ScenarioReport.write(#"{"pid":\#(processID),"sessionId":"\#(sessionID)"}"#, for: processID, in: reporting)
    }

    func showsItsHomeScreen() throws {
        try ScenarioReport.write(#"{"pid":\#(processID),"sessionId":null}"#, for: processID, in: reporting)
    }

    func saves(session sessionID: String, projectPath: String) throws {
        try database.addSession(sessionID, directory: projectPath)
    }
}

enum ScenarioReport {
    static func write(_ report: String, for processID: Int32, in reporting: LiveSessionReporting) throws {
        try FileManager.default.createDirectory(at: reporting.reportsDirectory, withIntermediateDirectories: true)
        try report.write(to: reporting.reportsDirectory.appendingPathComponent("\(processID).json"), atomically: true, encoding: .utf8)
    }
}
