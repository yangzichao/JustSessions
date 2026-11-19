import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
struct WorkingSpinnerLifecycleTests {
    @MainActor private final class Visibility: ObservableObject {
        @Published var isShown = true
        @Published var holdsStill = false
    }

    private struct SpinnerUnderTest: View {
        @ObservedObject var visibility: Visibility

        var body: some View {
            // The arc itself, told whether to turn: `WorkingSpinner` holds it still with Reduce Motion on, as GitHub's
            // macOS runners have it, and a test can't turn Reduce Motion off. `holdsStill` stands in for it.
            WorkingSpinnerArc(turns: !visibility.holdsStill)
                .frame(width: 10, height: 10)
                .opacity(visibility.isShown ? 1 : 0)
                .padding(7)
        }
    }

    @Test func fadingTheSpinnerOutWithOpacityStopsItAndFadingInStartsItAgain() async throws {
        let (window, hostingView, visibility) = try await makeWindow()
        defer { window.close() }
        let arc = try #require(findArc(in: hostingView))
        #expect(arc.isTurning)

        visibility.isShown = false
        try await settle(hostingView)
        #expect(!arc.canBeSeen)
        #expect(!arc.isTurning)

        visibility.isShown = true
        try await settle(hostingView)
        #expect(arc.canBeSeen)
        #expect(arc.isTurning)
    }

    @Test func hidingAnAncestorViewStopsItAndUnhidingStartsItAgain() async throws {
        let (window, hostingView, _) = try await makeWindow()
        defer { window.close() }
        let arc = try #require(findArc(in: hostingView))
        #expect(arc.isTurning)

        hostingView.isHidden = true
        #expect(!arc.isTurning)

        hostingView.isHidden = false
        #expect(arc.isTurning)
    }

    @Test func holdingTheArcStillStopsItAndLettingItTurnStartsIt() async throws {
        let (window, hostingView, visibility) = try await makeWindow()
        defer { window.close() }
        let arc = try #require(findArc(in: hostingView))

        visibility.holdsStill = true
        try await settle(hostingView)
        #expect(!arc.isTurning)
        #expect(arc.canBeSeen)

        visibility.holdsStill = false
        try await settle(hostingView)
        #expect(arc.isTurning)
    }

    @Test func leavingTheWindowStopsIt() async throws {
        let (window, hostingView, _) = try await makeWindow()
        defer { window.close() }
        let arc = try #require(findArc(in: hostingView))
        #expect(arc.isTurning)

        window.contentView = nil

        #expect(arc.window == nil)
        #expect(!arc.isTurning)
    }

    /// A borderless test window cannot really miniaturize, so the state is read back through `canBeSeen` with the
    /// window's notifications posted as AppKit posts them; the check itself is what `updateRotation` consults.
    @Test func theWindowsMiniaturizationNotificationsReachTheArc() async throws {
        let (window, hostingView, _) = try await makeWindow()
        defer { window.close() }
        let arc = try #require(findArc(in: hostingView))
        #expect(arc.isTurning)

        NotificationCenter.default.post(name: NSWindow.didMiniaturizeNotification, object: window)
        #expect(arc.canBeSeen)
        #expect(arc.isTurning)
        NotificationCenter.default.post(name: NSWindow.didDeminiaturizeNotification, object: window)
        #expect(arc.isTurning)
    }

    @Test func aMinimizedWindowStopsItAndRestoringTheWindowStartsItAgain() async throws {
        _ = NSApplication.shared
        // A window that can miniaturize is one with a title bar, shown first, as a user's window has been: AppKit
        // posts `didDeminiaturize` for a window restored to the screen, not for one that was never on it.
        let hostingView = NSHostingView(rootView: WorkingSpinnerArc(turns: true).frame(width: 10, height: 10).padding(7))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled, .miniaturizable], backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = hostingView
        window.orderFrontRegardless()
        try await settle(hostingView)
        let arc = try #require(findArc(in: hostingView))
        try #require(arc.canBeSeen && arc.isTurning)

        window.miniaturize(nil)
        try await waitUntil { !arc.isTurning }
        guard window.isMiniaturized else {
            // Without a window server session, as on CI, the window cannot miniaturize; nothing to check then.
            return
        }
        #expect(!arc.canBeSeen)
        #expect(!arc.isTurning)

        window.deminiaturize(nil)
        try await waitUntil { arc.isTurning }
        #expect(!window.isMiniaturized)
        #expect(arc.canBeSeen)
        #expect(arc.isTurning)
    }

    private func makeWindow() async throws -> (NSWindow, NSHostingView<SpinnerUnderTest>, Visibility) {
        _ = NSApplication.shared
        let visibility = Visibility()
        let hostingView = NSHostingView(rootView: SpinnerUnderTest(visibility: visibility))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 24, height: 24), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.orderFrontRegardless()
        try await settle(hostingView)
        return (window, hostingView, visibility)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(120)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    private func settle(_ hostingView: NSView) async throws {
        for _ in 0..<4 {
            hostingView.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    private func findArc(in view: NSView) -> WorkingSpinnerArcView? {
        (view as? WorkingSpinnerArcView) ?? view.subviews.lazy.compactMap(findArc).first
    }
}
