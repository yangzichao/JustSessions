import Testing

@testable import JustSessions

struct RandomTipRotationTests {
    @Test func showsEveryTipOnceBeforeAnyRepeats() {
        var rotation = RandomTipRotation(shownTips: [])
        var currentTip: RandomTip?
        var tipsInFirstRound: [RandomTip] = []
        for _ in RandomTip.allCases {
            currentTip = rotation.nextTip(after: currentTip, randomIndex: { _ in 0 })
            tipsInFirstRound.append(currentTip!)
        }
        #expect(Set(tipsInFirstRound) == Set(RandomTip.allCases))
        #expect(tipsInFirstRound.count == RandomTip.allCases.count)
    }

    @Test func picksAmongTheTipsNotShownYet() {
        let shownTips = Set(RandomTip.allCases.dropLast(2))
        var rotation = RandomTipRotation(shownTips: shownTips)
        var offeredCount: Int?

        let nextTip = rotation.nextTip(
            after: nil,
            randomIndex: { count in
                offeredCount = count
                return count - 1
            })

        #expect(offeredCount == 2)
        #expect(nextTip == RandomTip.allCases.last)
        #expect(rotation.shownTips == shownTips.union([nextTip]))
    }

    @Test func startsANewRoundWithoutRepeatingTheTipShowing() throws {
        let currentTip = try #require(RandomTip.allCases.first)
        var rotation = RandomTipRotation(shownTips: Set(RandomTip.allCases))
        var offeredCount: Int?

        let nextTip = rotation.nextTip(
            after: currentTip,
            randomIndex: { count in
                offeredCount = count
                return 0
            })

        #expect(offeredCount == RandomTip.allCases.count - 1)
        #expect(nextTip != currentTip)
        #expect(rotation.shownTips == [nextTip])
    }

    @Test func neverRepeatsTheTipShowingWhileOthersAreLeft() throws {
        let currentTip = try #require(RandomTip.allCases.last)
        var rotation = RandomTipRotation(shownTips: Set(RandomTip.allCases.dropFirst().dropLast()))

        // Only the first tip and the one showing are unshown; the one showing is never offered.
        let nextTip = rotation.nextTip(
            after: currentTip,
            randomIndex: { count in
                #expect(count == 1)
                return 0
            })

        #expect(nextTip == RandomTip.allCases.first)
    }
}
