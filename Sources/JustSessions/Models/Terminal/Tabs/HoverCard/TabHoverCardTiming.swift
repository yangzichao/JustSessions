import Foundation

struct TabHoverCardTiming {
    static let showWithoutDelayWindow: Duration = .milliseconds(300)
    static let hideDelay: Duration = .milliseconds(100)

    enum Wait: Equatable {
        case nothing
        case show(TabHoverCardTarget, after: Duration)
        case hide(after: Duration)
    }

    private(set) var shownTarget: TabHoverCardTarget?
    private(set) var hoveredTarget: TabHoverCardTarget?
    private var dismissedTarget: TabHoverCardTarget?
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

    mutating func showDelayElapsed(for target: TabHoverCardTarget) {
        guard hoveredTarget == target, dismissedTarget != target, !isMouseDown else { return }
        shownTarget = target
    }

    mutating func hideDelayElapsed(at now: ContinuousClock.Instant) {
        guard hoveredTarget == nil, shownTarget != nil else { return }
        shownTarget = nil
        lastHiddenAt = now
    }

    mutating func dismiss() {
        dismissedTarget = hoveredTarget
        shownTarget = nil
        lastHiddenAt = nil
    }

    mutating func mouseDown() {
        isMouseDown = true
        dismiss()
    }

    mutating func mouseUp() {
        isMouseDown = false
    }

    mutating func reset() {
        self = TabHoverCardTiming()
    }
}
