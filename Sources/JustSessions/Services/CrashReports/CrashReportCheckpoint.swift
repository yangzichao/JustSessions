import Foundation

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
