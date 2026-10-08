import Foundation
import Testing
@testable import JustSessions

@MainActor
struct LaunchCrashReportOfferTests {
    /// Collects the reports the offer shows.
    private final class ShownReports {
        var reports: [FoundCrashReport] = []
    }

    private func writeCrashReport(in directory: URL, writtenAt: Date) throws {
        let file = directory.appendingPathComponent("JustSessions-2026-10-05-100000.ips")
        try CrashReportSamples.reportText().write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: writtenAt], ofItemAtPath: file.path)
    }

    private func finder(in directory: URL) -> CrashReportFinder {
        CrashReportFinder(reportsDirectory: directory, executableName: "JustSessions", bundleIdentifier: CrashReportSamples.bundleIdentifier)
    }

    @Test func theFirstLookGoesBackAWeekAndEachLaterOneToThePreviousLook() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let checkpoint = CrashReportCheckpoint(userDefaults: settings.userDefaults)
        let now = Date.now

        #expect(checkpoint.lastCheck(before: now) == now.addingTimeInterval(-7 * 24 * 60 * 60))
        let lookedAt = now.addingTimeInterval(-60)
        checkpoint.record(lookedAt)
        #expect(checkpoint.lastCheck(before: now) == lookedAt)
    }

    @Test func aCrashSinceTheLastLaunchIsOfferedOnce() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeCrashReport(in: directory, writtenAt: .now.addingTimeInterval(-60))
        let shown = ShownReports()

        for _ in 0..<2 {
            await LaunchCrashReportOffer.offerIfTheLastRunCrashed(
                userDefaults: settings.userDefaults,
                finder: finder(in: directory),
                show: { shown.reports.append($0) }
            )?.value
        }

        #expect(shown.reports.map(\.file.lastPathComponent) == ["JustSessions-2026-10-05-100000.ips"])
    }

    @Test func turnedOffForALaunchItNeitherLooksNorMovesTheLastLook() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeCrashReport(in: directory, writtenAt: .now.addingTimeInterval(-60))
        settings.userDefaults.set(false, forKey: LaunchCrashReportOffer.userDefaultsKey)
        let shown = ShownReports()

        let offer = LaunchCrashReportOffer.offerIfTheLastRunCrashed(
            userDefaults: settings.userDefaults,
            finder: finder(in: directory),
            show: { shown.reports.append($0) }
        )

        #expect(offer == nil)
        #expect(shown.reports.isEmpty)
        #expect(settings.userDefaults.object(forKey: CrashReportCheckpoint.userDefaultsKey) == nil)
    }
}
