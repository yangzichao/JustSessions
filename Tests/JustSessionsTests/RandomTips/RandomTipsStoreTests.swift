import Foundation
import Testing

@testable import JustSessions

@MainActor
struct RandomTipsStoreTests {
    @Test func showsATipAtLaunchByDefault() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }

        let tipsStore = RandomTipsStore(userDefaults: isolatedUserDefaults.userDefaults, waitsForNextLaunch: false)

        #expect(tipsStore.showsTips)
        #expect(tipsStore.currentTip != nil)
    }

    @Test func aLaunchThatShowsTheTourShowsNoTipUntilTheNext() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let userDefaults = isolatedUserDefaults.userDefaults

        let tourLaunchTipsStore = RandomTipsStore(userDefaults: userDefaults, waitsForNextLaunch: true)
        #expect(tourLaunchTipsStore.showsTips)
        #expect(tourLaunchTipsStore.currentTip == nil)

        let nextLaunchTipsStore = RandomTipsStore(userDefaults: userDefaults, waitsForNextLaunch: false)
        #expect(nextLaunchTipsStore.currentTip != nil)
    }

    @Test func eachLaunchShowsATipTheLastOnesDidNot() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let userDefaults = isolatedUserDefaults.userDefaults

        var tipsShownAtLaunch: [RandomTip] = []
        for _ in RandomTip.allCases {
            let tipsStore = RandomTipsStore(userDefaults: userDefaults, waitsForNextLaunch: false, randomIndex: { _ in 0 })
            tipsShownAtLaunch.append(try #require(tipsStore.currentTip))
        }

        #expect(Set(tipsShownAtLaunch) == Set(RandomTip.allCases))
    }

    @Test func nextTipShowsAnotherAndHidingLastsUntilTheNextLaunch() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let userDefaults = isolatedUserDefaults.userDefaults
        let tipsStore = RandomTipsStore(userDefaults: userDefaults, waitsForNextLaunch: false)
        let firstTip = try #require(tipsStore.currentTip)

        tipsStore.showNextTip()
        #expect(tipsStore.currentTip != firstTip)

        tipsStore.hideUntilNextLaunch()
        #expect(tipsStore.currentTip == nil)
        #expect(tipsStore.showsTips)

        let relaunchedTipsStore = RandomTipsStore(userDefaults: userDefaults, waitsForNextLaunch: false)
        #expect(relaunchedTipsStore.currentTip != nil)
    }

    @Test func turningTipsOffHidesTheTipForGoodAndTurningThemOnShowsOneAtOnce() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let userDefaults = isolatedUserDefaults.userDefaults
        let tipsStore = RandomTipsStore(userDefaults: userDefaults, waitsForNextLaunch: false)

        tipsStore.setShowsTips(false)
        #expect(!tipsStore.showsTips)
        #expect(tipsStore.currentTip == nil)
        tipsStore.showNextTip()
        #expect(tipsStore.currentTip == nil)

        let relaunchedTipsStore = RandomTipsStore(userDefaults: userDefaults, waitsForNextLaunch: false)
        #expect(!relaunchedTipsStore.showsTips)
        #expect(relaunchedTipsStore.currentTip == nil)

        relaunchedTipsStore.setShowsTips(true)
        #expect(relaunchedTipsStore.showsTips)
        #expect(relaunchedTipsStore.currentTip != nil)
    }

    @Test func savesShownTipsInDeclarationOrderAndIgnoresUnknownSavedTips() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let userDefaults = isolatedUserDefaults.userDefaults
        let lastTip = try #require(RandomTip.allCases.last)
        let firstTip = try #require(RandomTip.allCases.first)
        userDefaults.set([lastTip.rawValue, "retiredTip"], forKey: RandomTipsStore.shownTipsKey)

        let tipsStore = RandomTipsStore(userDefaults: userDefaults, waitsForNextLaunch: false, randomIndex: { _ in 0 })

        #expect(tipsStore.currentTip == firstTip)
        #expect(userDefaults.stringArray(forKey: RandomTipsStore.shownTipsKey) == [firstTip.rawValue, lastTip.rawValue])
    }
}
