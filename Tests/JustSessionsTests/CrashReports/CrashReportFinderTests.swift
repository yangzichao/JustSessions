import Foundation
import Testing
@testable import JustSessions

struct CrashReportFinderTests {
    private let now = Date.now
    private var lastCheck: Date { now.addingTimeInterval(-3600) }

    private func writeReport(_ text: String, named fileName: String, writtenAt: Date, in directory: URL) throws {
        let file = directory.appendingPathComponent(fileName)
        try text.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: writtenAt], ofItemAtPath: file.path)
    }

    private func finder(in directory: URL) -> CrashReportFinder {
        CrashReportFinder(reportsDirectory: directory, executableName: "JustSessions", bundleIdentifier: CrashReportSamples.bundleIdentifier)
    }

    @Test func findsTheNewestCrashOfThisAppSinceTheLastCheck() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeReport(CrashReportSamples.reportText(appVersion: "1.0.4"), named: "JustSessions-2026-10-05-090000.ips",
                        writtenAt: now.addingTimeInterval(-120), in: directory)
        try writeReport(CrashReportSamples.reportText(appVersion: "1.0.5"), named: "JustSessions-2026-10-05-100000.ips",
                        writtenAt: now.addingTimeInterval(-60), in: directory)
        // Newer, but not a crash of this app: a hang, another build's crash, another app's, and another kind of file.
        try writeReport(CrashReportSamples.reportText(bugType: "298"), named: "JustSessions-2026-10-05-100100.ips",
                        writtenAt: now.addingTimeInterval(-50), in: directory)
        try writeReport(CrashReportSamples.reportText(bundleIdentifier: "dev.example.other"), named: "JustSessions-2026-10-05-100200.ips",
                        writtenAt: now.addingTimeInterval(-40), in: directory)
        try writeReport(CrashReportSamples.reportText(), named: "JustSessionsHelper-2026-10-05-100300.ips",
                        writtenAt: now.addingTimeInterval(-30), in: directory)
        try writeReport(CrashReportSamples.reportText(), named: "JustSessions-2026-10-05-100400.diag",
                        writtenAt: now.addingTimeInterval(-20), in: directory)

        let report = try #require(finder(in: directory).newestReport(writtenAfter: lastCheck))

        #expect(report.file.lastPathComponent == "JustSessions-2026-10-05-100000.ips")
        #expect(report.summary.appVersion == "1.0.5 (12)")
        #expect(abs(report.writtenAt.timeIntervalSince(now.addingTimeInterval(-60))) < 1)
    }

    @Test func aCrashFromBeforeTheLastCheckIsNotFoundAgain() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeReport(CrashReportSamples.reportText(), named: "JustSessions-2026-10-01-100000.ips",
                        writtenAt: lastCheck.addingTimeInterval(-1), in: directory)

        #expect(finder(in: directory).newestReport(writtenAfter: lastCheck) == nil)
    }

    @Test func aMissingReportsFolderFindsNothing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(finder(in: directory.appendingPathComponent("missing")).newestReport(writtenAfter: lastCheck) == nil)
    }

    @Test func onlyTheNewestReportsAreRead() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeReport(CrashReportSamples.reportText(), named: "JustSessions-2026-10-05-090000.ips",
                        writtenAt: now.addingTimeInterval(-600), in: directory)
        for index in 0..<CrashReportFinder.maximumReportsRead {
            try writeReport("not a report", named: "JustSessions-2026-10-05-1000\(10 + index).ips",
                            writtenAt: now.addingTimeInterval(-Double(index)), in: directory)
        }

        #expect(finder(in: directory).newestReport(writtenAfter: lastCheck) == nil)
    }
}
