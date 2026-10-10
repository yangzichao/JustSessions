import Foundation

/// When the tab bar's hover card shows and hides, as Chrome's `TabHoverCardController` decides. The first card waits
/// for the pointer to rest, see `TabHoverCardDelay`; while one shows, it moves to each tab or label the pointer
/// reaches at once, and a pointer back soon after the card hid gets one at once too. A press, a key, or a scroll hides
/// the card, and the tab or label under the pointer shows none again until the pointer leaves it.
struct TabHoverCardTiming {
    /// A pointer back on a tab or label this soon after the card hid gets a card at once, as Chrome's
    /// `kShowWithoutDelayTimeBuffer`.
    static let showWithoutDelayWindow: Duration = .milliseconds(300)
    /// The card stays this long after the pointer leaves its tab or label, so crossing the space between two groups
    /// moves it rather than hiding and showing it again.
    static let hideDelay: Duration = .milliseconds(100)

    /// What to wait for before the next step.
    enum Wait: Equatable {
        case nothing
        /// Show the card for the target once the pointer has rested on it this long.
        case show(TabHoverCardTarget, after: Duration)
        /// Hide the card after this long, unless the pointer reaches another tab or label meanwhile.
        case hide(after: Duration)
    }

    private(set) var shownTarget: TabHoverCardTarget?
    private(set) var hoveredTarget: TabHoverCardTarget?
    /// The tab or label a press, key, or scroll hid the card over, which shows none until the pointer leaves it.
    private var dismissedTarget: TabHoverCardTarget?
    /// The left button is down, as a click or drag begins, which shows no card for anything the pointer passes.
    private var isMouseDown = false
    private var lastHiddenAt: ContinuousClock.Instant?

    mutating func pointerEntered(_ target: TabHoverCardTarget, at now: ContinuousClock.Instant, showDelay: Duration) -> Wait {
        hoveredTarget = target
        if isMouseDown { dismissedTarget = target }
        guard dismissedTarget != target else { return .nothing }
        let hidJustNow = lastHiddenAt.map { now - $0 <= Self.showWithoutDelayWindow } ?? false
        if shownTarget != nil || hidJustNow {
            shownTarget = target
            return .nothing
        }
        return .show(target, after: showDelay)
    }

    mutating func pointerExited(_ target: TabHoverCardTarget) -> Wait {
        if dismissedTarget == target { dismissedTarget = nil }
        guard hoveredTarget == target else { return .nothing }
        hoveredTarget = nil
        return shownTarget == nil ? .nothing : .hide(after: Self.hideDelay)
    }

    /// The pointer rested on the target for its show delay.
    mutating func showDelayElapsed(for target: TabHoverCardTarget) {
        guard hoveredTarget == target, dismissedTarget != target, !isMouseDown else { return }
        shownTarget = target
    }

    /// The hide delay passed: the card goes, unless the pointer reached another tab or label meanwhile.
    mutating func hideDelayElapsed(at now: ContinuousClock.Instant) {
        guard hoveredTarget == nil, shownTarget != nil else { return }
        shownTarget = nil
        lastHiddenAt = now
    }

    /// A key or a scroll hides the card. The next one waits its delay again.
    mutating func dismiss() {
        dismissedTarget = hoveredTarget
        shownTarget = nil
        lastHiddenAt = nil
    }

    /// The left button went down, as a click or a drag begins.
    mutating func mouseDown() {
        isMouseDown = true
        dismiss()
    }

    mutating func mouseUp() {
        isMouseDown = false
    }

    /// The app went to the background, where the pointer's place is unknown.
    mutating func reset() {
        self = TabHoverCardTiming()
    }
}
