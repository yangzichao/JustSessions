import AppKit
import Testing
@testable import JustSessions

@MainActor
struct AppAppearanceStoreTests {
    @Test func chosenAppearanceIsSetOnTheAppAndSurvivesReopening() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let application = RecordedApplicationAppearance()
        let store = AppAppearanceStore(userDefaults: settings.userDefaults, setApplicationAppearance: application.set)
        #expect(store.mode == .system)

        store.applyToApplication()
        store.setMode(.dark)
        store.setMode(.dark)
        store.setMode(.light)

        let reopened = AppAppearanceStore(userDefaults: settings.userDefaults, setApplicationAppearance: application.set)
        #expect(reopened.mode == .light)
        reopened.applyToApplication()
        reopened.setMode(.system)

        #expect(application.appliedNames == [nil, .darkAqua, .aqua, .aqua, nil])
        #expect(AppAppearanceMode.load(from: settings.userDefaults) == .system)
    }

    @Test func unknownSavedAppearanceFallsBackToSystem() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set("sepia", forKey: AppAppearanceMode.userDefaultsKey)

        #expect(AppAppearanceStore(userDefaults: settings.userDefaults) { _ in }.mode == .system)
    }
}

/// Stands in for `NSApp`, which unit tests run without.
@MainActor
private final class RecordedApplicationAppearance {
    private(set) var appliedNames: [NSAppearance.Name?] = []

    func set(_ appearance: NSAppearance?) {
        appliedNames.append(appearance?.name)
    }
}
