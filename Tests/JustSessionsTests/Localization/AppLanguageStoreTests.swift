import Combine
import Foundation
import Testing
@testable import JustSessions

@MainActor
struct AppLanguageStoreTests {
    @Test func defaultsToSystemAndDiscoversPackagedLanguages() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppLanguageStore(userDefaults: settings.userDefaults)
        #expect(store.language == .followSystem)
        #expect(store.choices.first == .followSystem)
        #expect(Set(["en", "zh-Hans"]).isSubset(of: Set(store.choices.compactMap(\.identifier))))
    }

    @Test func savesExplicitLanguageAndClearsOverrideWhenFollowingSystem() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppLanguageStore(userDefaults: settings.userDefaults)
        let chinese = AppInterfaceLanguage(identifier: "zh-Hans")
        store.setLanguage(chinese)
        #expect(AppLanguageStore(userDefaults: settings.userDefaults).language == chinese)
        store.setLanguage(.followSystem)
        #expect(settings.userDefaults.object(forKey: AppLanguageStore.userDefaultsKey) == nil)
        #expect(AppLanguageStore(userDefaults: settings.userDefaults).language == .followSystem)
    }

    @Test func rejectsUnavailableLanguageAndRecoversFromRemovedOrInvalidPreference() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set("removed-language", forKey: AppLanguageStore.userDefaultsKey)
        let store = AppLanguageStore(userDefaults: settings.userDefaults)
        #expect(store.language == .followSystem)
        #expect(settings.userDefaults.object(forKey: AppLanguageStore.userDefaultsKey) == nil)
        store.setLanguage(AppInterfaceLanguage(identifier: "not-packaged"))
        #expect(store.language == .followSystem)
    }

    @Test func additionalLanguageAppearsAndPersistsWithoutNewCasesOrBranches() throws {
        let fixture = try LocalizationBundleFixture()
        defer { fixture.remove() }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppLanguageStore(userDefaults: settings.userDefaults, bundle: fixture.bundle)
        let japanese = AppInterfaceLanguage(identifier: "ja")
        #expect(store.choices.contains(japanese))
        #expect(japanese.nativeName == "日本語")
        store.setLanguage(japanese)
        #expect(store.locale.identifier == "ja")
        #expect(AppLanguageStore(userDefaults: settings.userDefaults, bundle: fixture.bundle).language == japanese)
        #expect(AppLocalization.string("General", language: japanese, bundle: fixture.bundle) == "一般")
        #expect(AppLocalization.string("General", language: .followSystem, bundle: fixture.bundle, preferredLanguages: ["ja-JP"]) == "一般")
        // A key without a Japanese translation falls back to its English source rather than an empty label.
        #expect(AppLocalization.string("English fallback", language: japanese, bundle: fixture.bundle) == "English fallback")
        let englishOnlyFixture = try LocalizationBundleFixture(localizations: ["en"])
        defer { englishOnlyFixture.remove() }
        #expect(AppLanguageStore(userDefaults: settings.userDefaults, bundle: englishOnlyFixture.bundle).language == .followSystem)
    }

    @Test func systemLocaleChangesRefreshViewsFollowingSystem() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let notifications = NotificationCenter()
        let store = AppLanguageStore(userDefaults: settings.userDefaults, notificationCenter: notifications)
        var changeCount = 0
        let observation = store.objectWillChange.sink { changeCount += 1 }
        defer { observation.cancel() }
        notifications.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        try await expectEventually { changeCount == 1 }
        #expect(store.language == .followSystem)
    }
}
