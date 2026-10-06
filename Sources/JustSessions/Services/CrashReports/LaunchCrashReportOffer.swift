import Foundation

/// At launch, offers to report the newest crash macOS recorded since the last launch. The look is saved before the
/// files are read, so each crash is offered once, and one while the offer shows is offered next time.
@MainActor
enum LaunchCrashReportOffer {
    /// `make verify` turns the offer off for its launch with `-offersCrashReportsAtLaunch '<false/>'`, so the check
    /// neither shows the offer nor moves the saved look on.
    static let userDefaultsKey = "offersCrashReportsAtLaunch"

    /// The returned task reads the reports and shows the offer; nil when the offer is turned off.
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
