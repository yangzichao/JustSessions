import Foundation
import Testing
@testable import JustSessions

@MainActor
struct OnboardingTipsStoreTests {
    @Test func freshInstallShowsEveryTipOnceAcrossRelaunches() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let tipsStore = OnboardingTipsStore(userDefaults: isolatedUserDefaults.userDefaults, isFreshInstall: true)
        #expect(tipsStore.shouldShow(.tour))
        #expect(tipsStore.shouldShow(.keepRunning))

        tipsStore.markShown(.tour)

        let relaunchedTipsStore = OnboardingTipsStore(userDefaults: isolatedUserDefaults.userDefaults, isFreshInstall: true)
        #expect(!relaunchedTipsStore.shouldShow(.tour))
        #expect(relaunchedTipsStore.shouldShow(.keepRunning))
    }

    @Test func existingInstallShowsNoTipEvenAfterItsSettingsLookFresh() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let tipsStore = OnboardingTipsStore(userDefaults: isolatedUserDefaults.userDefaults, isFreshInstall: false)
        #expect(tipsStore.tipsToShow.isEmpty)

        // Whether the install is fresh is decided once; later launches read the saved answer.
        var askedWhetherFresh = false
        let relaunchedTipsStore = OnboardingTipsStore(
            userDefaults: isolatedUserDefaults.userDefaults,
            isFreshInstall: { askedWhetherFresh = true; return true }()
        )
        #expect(relaunchedTipsStore.tipsToShow.isEmpty)
        #expect(!askedWhetherFresh)
    }

    @Test func savesTipsInDeclarationOrderAndIgnoresUnknownSavedTips() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let userDefaults = isolatedUserDefaults.userDefaults
        userDefaults.set(["keepRunning", "retiredTip", "tour"], forKey: OnboardingTipsStore.userDefaultsKey)

        let tipsStore = OnboardingTipsStore(userDefaults: userDefaults, isFreshInstall: false)
        #expect(tipsStore.tipsToShow == [.tour, .keepRunning])

        tipsStore.markShown(.keepRunning)
        #expect(userDefaults.stringArray(forKey: OnboardingTipsStore.userDefaultsKey) == ["tour"])
    }
}
