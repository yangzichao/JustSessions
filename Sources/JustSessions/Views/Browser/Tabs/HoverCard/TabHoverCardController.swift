import CoreGraphics
import SwiftUI

extension EnvironmentValues {
    /// The window's hover card, which the tab bar's tabs and group labels report the pointer to. Nil shows none.
    @Entry var tabHoverCards: TabHoverCardController? = nil
}

/// Runs one window's tab bar hover card: follows the pointer over tabs and group labels, and waits and hides as
/// `TabHoverCardTiming` decides. `TabHoverCardEventWatcher` reports presses, keys, and scrolls.
@MainActor
final class TabHoverCardController: ObservableObject {
    /// The card that shows, and where its tab or label sits in the window.
    struct ShownCard: Equatable {
        let target: TabHoverCardTarget
        let anchorFrame: CGRect
    }

    @Published private(set) var shownCard: ShownCard?
    private var timing = TabHoverCardTiming()
    /// Where each tab and group label sits in the window. Kept out of `shownCard` until its card shows, so tabs moving
    /// as they narrow, slide, or scroll redraw nothing.
    private var anchorFramesByTarget: [TabHoverCardTarget: CGRect] = [:]
    private var pendingShow: Task<Void, Never>?
    private var pendingHide: Task<Void, Never>?

    /// - Parameter tabWidth: the width the bar's tabs share, which sets how long the first card waits.
    func pointerEntered(_ target: TabHoverCardTarget, tabWidth: CGFloat) {
        let wait = timing.pointerEntered(target, at: .now, showDelay: TabHoverCardDelay.beforeShowing(tabWidth: tabWidth))
        follow(wait)
    }

    func pointerExited(_ target: TabHoverCardTarget) {
        follow(timing.pointerExited(target))
    }

    func mouseDown() {
        timing.mouseDown()
        publish()
    }

    func mouseUp() {
        timing.mouseUp()
    }

    func dismiss() {
        timing.dismiss()
        publish()
    }

    /// Where the tab or label sits in the window, or nil once it is gone.
    func report(_ anchorFrame: CGRect?, of target: TabHoverCardTarget) {
        anchorFramesByTarget[target] = anchorFrame
        if target == timing.shownTarget { publish() }
    }

    func reset() {
        pendingShow?.cancel()
        pendingHide?.cancel()
        timing.reset()
        publish()
    }

    private func follow(_ wait: TabHoverCardTiming.Wait) {
        publish()
        switch wait {
        case .nothing:
            break
        case .show(let target, let delay):
            pendingShow?.cancel()
            pendingShow = Task { [weak self] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                timing.showDelayElapsed(for: target)
                publish()
            }
        case .hide(let delay):
            pendingHide?.cancel()
            pendingHide = Task { [weak self] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                timing.hideDelayElapsed(at: .now)
                publish()
            }
        }
    }

    private func publish() {
        let card = timing.shownTarget.flatMap { target in
            anchorFramesByTarget[target].map { ShownCard(target: target, anchorFrame: $0) }
        }
        if shownCard != card {
            shownCard = card
        }
    }
}
