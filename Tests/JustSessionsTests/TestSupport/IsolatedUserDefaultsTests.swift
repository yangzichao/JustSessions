import Foundation
import Testing

/// A test's settings live in a folder of its own and go with it, leaving nothing in `~/Library/Preferences`.
struct IsolatedUserDefaultsTests {
    private var preferencesDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Preferences")
    }

    @Test func settingsAreSavedInTheSuitesOwnFolderAndRemovedWithIt() async throws {
        let settings = try IsolatedUserDefaults()
        settings.userDefaults.set("value", forKey: "key")
        let plist = settings.directory.appendingPathComponent("settings.plist")
        try await expectEventually { FileManager.default.fileExists(atPath: plist.path) }
        #expect(!FileManager.default.fileExists(atPath: preferencesDirectory.appendingPathComponent("\(settings.suiteName).plist").path))
        #expect(!FileManager.default.fileExists(atPath: preferencesDirectory.appendingPathComponent(settings.directory.lastPathComponent + ".plist").path))

        settings.removeSuite()

        #expect(!FileManager.default.fileExists(atPath: settings.directory.path))
        #expect(settings.userDefaults.object(forKey: "key") == nil)
    }

    @Test func twoSuitesKeepTheirOwnSettings() throws {
        let first = try IsolatedUserDefaults()
        let second = try IsolatedUserDefaults()
        defer {
            first.removeSuite()
            second.removeSuite()
        }
        first.userDefaults.set("first", forKey: "key")

        #expect(first.userDefaults.string(forKey: "key") == "first")
        #expect(second.userDefaults.string(forKey: "key") == nil)
        #expect(UserDefaults.standard.string(forKey: "key") != "first")
    }
}
