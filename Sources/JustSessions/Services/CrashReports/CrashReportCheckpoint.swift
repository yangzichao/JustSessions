import Foundation

/// When the app last looked for crash reports, so each crash is offered for reporting once. With no look saved, it
/// goes back a week, so a crash just before updating to the first version that offers reports is still offered.
struct CrashReportCheckpoint {
    static let userDefaultsKey = "crashReportsCheckedAt"
    static let firstLookBack: TimeInterval = 7 * 24 * 60 * 60

    let userDefaults: UserDefaults

    func lastCheck(before now: Date) -> Date {
        userDefaults.object(forKey: Self.userDefaultsKey) as? Date ?? now.addingTimeInterval(-Self.firstLookBack)
    }

    func record(_ date: Date) {
        userDefaults.set(date, forKey: Self.userDefaultsKey)
    }
}
