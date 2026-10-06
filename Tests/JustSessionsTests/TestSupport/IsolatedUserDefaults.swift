import Foundation
import Testing

/// A settings suite of the test's own, so it never reads or changes the settings of the app or of other tests.
///
/// The suite is named by an absolute path, which `CFPreferences` takes as the location of its plist, in a folder of its
/// own under the temporary directory; `removeSuite()` deletes that folder. A suite named like an app's would keep its
/// plist in `~/Library/Preferences`, where removing its domain only empties the file, and the preferences daemon writes
/// the empty file back after the test process exits even when the test deletes it. Every test run left about a thousand.
struct IsolatedUserDefaults {
    let directory: URL
    let suiteName: String
    let userDefaults: UserDefaults

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JustSessionsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = directory.appendingPathComponent("settings").path
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
    }

    func removeSuite() {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
}
