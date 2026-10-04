import SwiftUI

/// Runs a workspace window's onboarding: the tour once a fresh install has listed This Mac's sessions at its first
/// launch, and the Keep running tip on the first tab that can keep running. Help and the Help menu start the tour again.
struct OnboardingTipsPresenter: ViewModifier {
    @ObservedObject var store: ConversationStore
    @ObservedObject var tour: OnboardingTour
    let tipsStore: OnboardingTipsStore
    let listsProjectWithSessions: Bool
    /// No sheet, alert, or dialog is up, so a tip that starts now shows right away.
    let isReadyForTips: Bool
    /// Shows the sidebar, where the tour starts.
    let onStartTour: () -> Void

    /// How long the sidebar gets to draw what was found, so the tour starts on it.
    static let tourStartDelay: Duration = .milliseconds(600)
    /// How long a tab stays selected before its tip shows, so it doesn't flash while tabs are switched.
    static let keepRunningTipDelay: Duration = .seconds(1)

    private struct FirstLaunchTourTrigger: Equatable {
        let hasListedThisMac: Bool
        let isReadyForTips: Bool
    }

    private struct KeepRunningTipTrigger: Equatable {
        let selectedTabID: UUID?
        let isTourRunning: Bool
        let isReadyForTips: Bool
    }

    private var hasListedThisMac: Bool {
        switch store.hostRefreshStatuses[.thisMac] {
        case .refreshed?, .failed?: true
        case .refreshing?, nil: false
        }
    }

    private var selectedTabCanKeepRunning: Bool {
        store.selectedTerminal?.canKeepCLIRunningAfterClose == true
    }

    func body(content: Content) -> some View {
        content
            .environment(\.onboardingTour, tour)
            .environment(\.startOnboardingTour, StartOnboardingTourAction(start: startTour))
            .focusedSceneValue(\.startOnboardingTour, isReadyForTips ? StartOnboardingTourAction(start: startTour) : nil)
            .task(id: FirstLaunchTourTrigger(hasListedThisMac: hasListedThisMac, isReadyForTips: isReadyForTips)) {
                await startTourAtFirstLaunch()
            }
            .task(id: KeepRunningTipTrigger(
                selectedTabID: store.selectedTerminalID,
                isTourRunning: tour.isRunning,
                isReadyForTips: isReadyForTips
            )) {
                await showKeepRunningTip()
            }
    }

    private func startTourAtFirstLaunch() async {
        guard tipsStore.shouldShow(.tour), hasListedThisMac, isReadyForTips, !tour.isRunning else { return }
        do { try await Task.sleep(for: Self.tourStartDelay) } catch { return }
        // Another workspace window may have started it meanwhile.
        guard tipsStore.shouldShow(.tour) else { return }
        startTour()
    }

    private func startTour() {
        let stops = OnboardingTourStop.tour(
            listsProjectWithSessions: listsProjectWithSessions,
            selectedTabCanKeepRunning: selectedTabCanKeepRunning
        )
        tipsStore.markShown(.tour)
        if stops.contains(.keepRunning) { tipsStore.markShown(.keepRunning) }
        onStartTour()
        tour.start(stops)
    }

    private func showKeepRunningTip() async {
        guard tipsStore.shouldShow(.keepRunning), store.selectedTerminalID != nil, isReadyForTips, !tour.isRunning
        else { return }
        do { try await Task.sleep(for: Self.keepRunningTipDelay) } catch { return }
        guard tipsStore.shouldShow(.keepRunning), selectedTabCanKeepRunning else { return }
        tipsStore.markShown(.keepRunning)
        tour.start([.keepRunning])
    }
}
