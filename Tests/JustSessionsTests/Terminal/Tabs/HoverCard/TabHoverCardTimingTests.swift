import Foundation
import Testing
@testable import JustSessions

/// The hover card waits for the pointer to rest before the first card, then follows it from tab to tab at once, as in
/// Chrome; a press, key, or scroll hides it until the pointer moves on.
struct TabHoverCardTimingTests {
    private let firstTab = TabHoverCardTarget.tab(UUID())
    private let secondTab = TabHoverCardTarget.tab(UUID())
    private let group = TabHoverCardTarget.group("/Users/me/project")
    private let delay = Duration.milliseconds(300)
    private let start = ContinuousClock.now

    @Test func theFirstCardWaitsForThePointerToRest() {
        var timing = TabHoverCardTiming()

        let wait = timing.pointerEntered(firstTab, at: start, showDelay: delay)

        #expect(wait == .show(firstTab, after: delay))
        #expect(timing.shownTarget == nil)
        timing.showDelayElapsed(for: firstTab)
        #expect(timing.shownTarget == firstTab)
    }

    @Test func aPointerThatMovedOnBeforeTheDelayShowsNoCardForTheTabItLeft() {
        var timing = TabHoverCardTiming()
        _ = timing.pointerEntered(firstTab, at: start, showDelay: delay)
        _ = timing.pointerExited(firstTab)

        timing.showDelayElapsed(for: firstTab)

        #expect(timing.shownTarget == nil)
    }

    @Test func whileACardShowsItMovesToTheNextTabAtOnce() {
        var timing = shownOn(firstTab)

        _ = timing.pointerExited(firstTab)
        let wait = timing.pointerEntered(secondTab, at: start, showDelay: delay)

        #expect(wait == .nothing)
        #expect(timing.shownTarget == secondTab)
    }

    @Test func theCardMovesAtOnceWhenTheNextTabIsEnteredBeforeTheLastIsLeft() {
        var timing = shownOn(firstTab)

        _ = timing.pointerEntered(secondTab, at: start, showDelay: delay)
        let wait = timing.pointerExited(firstTab)

        #expect(wait == .nothing)
        #expect(timing.shownTarget == secondTab)
    }

    @Test func theCardStaysWhileThePointerCrossesToTheNextGroupsLabel() {
        var timing = shownOn(firstTab)

        let wait = timing.pointerExited(firstTab)
        #expect(wait == .hide(after: TabHoverCardTiming.hideDelay))
        _ = timing.pointerEntered(group, at: start, showDelay: delay)
        timing.hideDelayElapsed(at: start)

        #expect(timing.shownTarget == group)
    }

    @Test func theCardHidesOnceThePointerLeavesTheBar() {
        var timing = shownOn(firstTab)

        _ = timing.pointerExited(firstTab)
        timing.hideDelayElapsed(at: start)

        #expect(timing.shownTarget == nil)
    }

    @Test func aPointerBackSoonAfterTheCardHidGetsOneAtOnce() {
        var timing = shownOn(firstTab)
        _ = timing.pointerExited(firstTab)
        timing.hideDelayElapsed(at: start)

        let wait = timing.pointerEntered(secondTab, at: start + .milliseconds(250), showDelay: delay)

        #expect(wait == .nothing)
        #expect(timing.shownTarget == secondTab)
    }

    @Test func aPointerBackLaterWaitsAgain() {
        var timing = shownOn(firstTab)
        _ = timing.pointerExited(firstTab)
        timing.hideDelayElapsed(at: start)

        let wait = timing.pointerEntered(secondTab, at: start + .milliseconds(400), showDelay: delay)

        #expect(wait == .show(secondTab, after: delay))
        #expect(timing.shownTarget == nil)
    }

    @Test func aKeyHidesTheCardUntilThePointerLeavesTheTab() {
        var timing = shownOn(firstTab)

        timing.dismiss()
        #expect(timing.shownTarget == nil)
        #expect(timing.pointerEntered(firstTab, at: start, showDelay: delay) == .nothing)
        timing.showDelayElapsed(for: firstTab)
        #expect(timing.shownTarget == nil)

        _ = timing.pointerExited(firstTab)
        #expect(timing.pointerEntered(secondTab, at: start, showDelay: delay) == .show(secondTab, after: delay))
    }

    @Test func aDismissedCardWaitsItsDelayOnTheNextTab() {
        var timing = shownOn(firstTab)
        timing.dismiss()
        _ = timing.pointerExited(firstTab)

        let wait = timing.pointerEntered(secondTab, at: start + .milliseconds(50), showDelay: delay)

        #expect(wait == .show(secondTab, after: delay))
    }

    @Test func noCardShowsForTabsPassedWhileTheButtonIsDown() {
        var timing = shownOn(firstTab)

        timing.mouseDown()
        #expect(timing.shownTarget == nil)
        _ = timing.pointerExited(firstTab)
        #expect(timing.pointerEntered(secondTab, at: start, showDelay: delay) == .nothing)
        timing.mouseUp()
        timing.showDelayElapsed(for: secondTab)

        #expect(timing.shownTarget == nil)
    }

    @Test func aPendingCardDoesNotShowOnceTheButtonGoesDown() {
        var timing = TabHoverCardTiming()
        _ = timing.pointerEntered(firstTab, at: start, showDelay: delay)

        timing.mouseDown()
        timing.showDelayElapsed(for: firstTab)

        #expect(timing.shownTarget == nil)
    }

    @Test func goingToTheBackgroundForgetsThePointer() {
        var timing = shownOn(firstTab)

        timing.reset()

        #expect(timing.shownTarget == nil)
        #expect(timing.hoveredTarget == nil)
        #expect(timing.pointerEntered(firstTab, at: start, showDelay: delay) == .show(firstTab, after: delay))
    }

    private func shownOn(_ target: TabHoverCardTarget) -> TabHoverCardTiming {
        var timing = TabHoverCardTiming()
        _ = timing.pointerEntered(target, at: start, showDelay: delay)
        timing.showDelayElapsed(for: target)
        return timing
    }
}
