import Foundation

@MainActor
enum LaunchCrashReportOffer {
    static let userDefaultsKey = "offersCrashReportsAtLaunch"

    @discardableResult
    static func offerIfTheLastRunCrashed(
        userDefaults: UserDefaults = .standard,
        finder: CrashReportFinder = CrashReportFinder(),
        show: @escaping @MainActor (FoundCrashReport) -> Void = CrashReportAlert.show
    ) -> Task<Void, Never>? {
        guard userDefaults.object(forKey: userDefaultsKey) as? Bool ?? true else { return nil }
        let checkpoint = CrashReportCheckpoint(userDefaults: userDefaults)
        let launchedAt = Date.now
        let lastCheck = checkpoint.lastCheck(before: launchedAt)
        checkpoint.record(launchedAt)
        return Task.detached(priority: .utility) {
            guard let report = finder.newestReport(writtenAfter: lastCheck) else { return }
            await show(report)
        }
    }
}
