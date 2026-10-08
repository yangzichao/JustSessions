import Foundation
import Testing
@testable import JustSessions

@MainActor
struct OnboardingTipsStoreTests {
    @Test func freshInstallShowsEveryTipOnceAcrossRelaunches() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let tipsStore = OnboardingTipsStore(userDefaults: isolatedUserDefaults.userDefaults, isFreshInstall: true)
        #expect(tipsStore.tipsToShow == Set(OnboardingTip.allCases))

        tipsStore.markShown(.tour)
        tipsStore.markShown(.readingSession)

        let relaunchedTipsStore = OnboardingTipsStore(userDefaults: isolatedUserDefaults.userDefaults, isFreshInstall: false)
        #expect(!relaunchedTipsStore.shouldShow(.tour))
        #expect(!relaunchedTipsStore.shouldShow(.readingSession))
        #expect(relaunchedTipsStore.shouldShow(.terminalTab))
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

    @Test func showingEveryTipAgainCoversAnExistingInstallAcrossRelaunches() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let tipsStore = OnboardingTipsStore(userDefaults: isolatedUserDefaults.userDefaults, isFreshInstall: false)
        #expect(tipsStore.tipsToShow.isEmpty)

        tipsStore.showEveryTipAgain()
        #expect(tipsStore.tipsToShow == Set(OnboardingTip.allCases))
        tipsStore.markShown(.tour)

        let relaunchedTipsStore = OnboardingTipsStore(userDefaults: isolatedUserDefaults.userDefaults, isFreshInstall: false)
        #expect(relaunchedTipsStore.tipsToShow == Set(OnboardingTip.allCases).subtracting([.tour]))
    }

    @Test func showingEveryTipAgainForgetsTheTipsShownBefore() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let tipsStore = OnboardingTipsStore(userDefaults: isolatedUserDefaults.userDefaults, isFreshInstall: true)
        for tip in OnboardingTip.allCases { tipsStore.markShown(tip) }
        #expect(tipsStore.tipsToShow.isEmpty)

        tipsStore.showEveryTipAgain()

        #expect(tipsStore.shouldShow(.readingSession))
        #expect(tipsStore.tipsToShow == Set(OnboardingTip.allCases))
    }

    @Test func savesShownTipsInDeclarationOrderAndIgnoresUnknownSavedTips() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let userDefaults = isolatedUserDefaults.userDefaults
        userDefaults.set(true, forKey: OnboardingTipsStore.showsTipsKey)
        userDefaults.set(["keepRunning", "retiredTip", "tour"], forKey: OnboardingTipsStore.shownTipsKey)

        let tipsStore = OnboardingTipsStore(userDefaults: userDefaults, isFreshInstall: false)
        // Tips added since those were saved still show.
        #expect(tipsStore.tipsToShow == Set(OnboardingTip.allCases).subtracting([.tour, .keepRunning]))

        tipsStore.markShown(.readingSession)
        #expect(userDefaults.stringArray(forKey: OnboardingTipsStore.shownTipsKey) == ["tour", "readingSession", "keepRunning"])
    }
}
