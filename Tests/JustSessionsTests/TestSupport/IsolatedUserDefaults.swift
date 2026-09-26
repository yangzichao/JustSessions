import Foundation
import Testing

/// A settings suite of the test's own, so it never reads or changes the settings of the app or of other tests.
struct IsolatedUserDefaults {
    let suiteName = "JustSessionsTests-\(UUID().uuidString)"
    let userDefaults: UserDefaults

    init() throws {
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
    }

    func removeSuite() {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
}
