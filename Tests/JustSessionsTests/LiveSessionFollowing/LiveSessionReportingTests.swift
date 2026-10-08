import Foundation
import Testing
@testable import JustSessions

struct LiveSessionReportingTests {
    @Test func piStartsWithTheExtensionThatReportsItsSession() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reporting = LiveSessionReporting(directory: directory)

        let launch = try #require(reporting.launchAdditions(for: .pi, environment: [:]))

        let extensionFile = directory.appendingPathComponent("pi/\(PiLiveSessionExtension.fileName)")
        #expect(launch.arguments == ["--extension", extensionFile.path])
        #expect(launch.environment == [LiveSessionReporting.reportsDirectoryVariable: reporting.reportsDirectory.path])
        #expect(try String(contentsOf: extensionFile, encoding: .utf8) == PiLiveSessionExtension.source)
    }

    @Test func openCodeLoadsThePluginThroughATUIConfiguration() throws {
        let directory = try makeTemporaryDirectory().appendingPathComponent("Application Support")
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let reporting = LiveSessionReporting(directory: directory)

        let launch = try #require(reporting.launchAdditions(for: .opencode, environment: [:]))

        let tuiConfigurationFile = directory.appendingPathComponent("opencode/tui.json")
        let pluginFile = directory.appendingPathComponent("opencode/\(OpenCodeLiveSessionPlugin.fileName)")
        #expect(launch.arguments.isEmpty)
        #expect(launch.environment == [
            LiveSessionReporting.reportsDirectoryVariable: reporting.reportsDirectory.path,
            OpenCodeLiveSessionPlugin.tuiConfigurationVariable: tuiConfigurationFile.path,
        ])
        let tuiConfiguration = try JSONSerialization.jsonObject(with: Data(contentsOf: tuiConfigurationFile)) as? [String: [String]]
        #expect(tuiConfiguration == ["plugin": [pluginFile.path]])
        #expect(try String(contentsOf: pluginFile, encoding: .utf8) == OpenCodeLiveSessionPlugin.source)
    }

    @Test func aTUIConfigurationOfTheUsersOwnStaysInPlace() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reporting = LiveSessionReporting(directory: directory)

        #expect(reporting.launchAdditions(for: .opencode, environment: ["OPENCODE_TUI_CONFIG": "/Users/me/tui.json"]) == nil)
        for provider in [ConversationProvider.claude, .codex, .antigravity, .kiro] {
            #expect(reporting.launchAdditions(for: provider, environment: [:]) == nil)
        }
    }

    @Test func readsOnlyTheReportOfTheProcessThatWroteIt() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reporting = LiveSessionReporting(directory: directory)
        try FileManager.default.createDirectory(at: reporting.reportsDirectory, withIntermediateDirectories: true)
        let sessionFile = "/Users/me/.pi/agent/sessions/--Users-me-app--/2026-10-04T23-00-26-198Z_01a10925-abd5-7606-8b40-1c56e397895e.jsonl"
        try #"{"pid":4242,"sessionId":"01a10925-abd5-7606-8b40-1c56e397895e","sessionFile":"\#(sessionFile)"}"#
            .write(to: reporting.reportsDirectory.appendingPathComponent("4242.json"), atomically: true, encoding: .utf8)
        try #"{"pid":1,"sessionId":"01a10925-abd5-7606-8b40-1c56e397895e"}"#
            .write(to: reporting.reportsDirectory.appendingPathComponent("4343.json"), atomically: true, encoding: .utf8)
        try #"{"pid":4444,"sessionId":null}"#
            .write(to: reporting.reportsDirectory.appendingPathComponent("4444.json"), atomically: true, encoding: .utf8)

        let report = try #require(reporting.report(forProcessID: 4242))
        #expect(report.sessionID == "01a10925-abd5-7606-8b40-1c56e397895e")
        #expect(report.sessionFile == URL(fileURLWithPath: sessionFile))
        #expect(reporting.report(forProcessID: 4343) == nil)
        #expect(reporting.report(forProcessID: 4444)?.sessionID == nil)
        #expect(reporting.report(forProcessID: 4545) == nil)
    }

    @Test func readsWhatTheCLIIsDoing() throws {
        let activities = try [
            #"{"pid":7,"sessionId":"s","activity":"working"}"#,
            #"{"pid":7,"sessionId":"s","activity":"waiting","waitingFor":"permission"}"#,
            #"{"pid":7,"sessionId":"s","activity":"waiting","waitingFor":" "}"#,
            #"{"pid":7,"sessionId":"s","activity":"waiting","waitingFor":"Dangerous command:\n\n  rm -rf build\n\nAllow?"}"#,
            #"{"pid":7,"sessionId":"s","activity":"idle"}"#,
            #"{"pid":7,"sessionId":"s","activity":"compacting"}"#,
            // Pi before 0.80.4 tells no activity.
            #"{"pid":7,"sessionId":"s"}"#,
            // OpenCode's home screen shows no session.
            #"{"pid":7,"sessionId":null,"activity":"idle"}"#,
        ].map { try #require(LiveSessionReport(jsonData: Data($0.utf8), processID: 7)).activity }

        #expect(activities == [
            .working,
            .needsInput(reason: "permission"),
            .needsInput(reason: nil),
            .needsInput(reason: "Dangerous command: rm -rf build Allow?"),
            .idle,
            nil,
            nil,
            nil,
        ])
    }
}
