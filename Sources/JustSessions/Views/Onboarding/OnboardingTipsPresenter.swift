import SwiftUI

/// Runs a workspace window's onboarding: the tour once a fresh install has listed This Mac's sessions at its first
/// launch, then each tip the first time what it is about comes into use, such as reading a session or opening a tab.
/// Help and the Help menu start the tour again.
struct OnboardingTipsPresenter: ViewModifier {
    @ObservedObject var store: ConversationStore
    @ObservedObject var tour: OnboardingTour
    let tipsStore: OnboardingTipsStore
    let listsProjectWithSessions: Bool
    /// The session whose conversation shows; nil while a tab, or nothing, shows instead.
    let readSession: Conversation?
    let isSidebarShown: Bool
    /// No sheet, alert, or dialog is up, so a tip that starts now shows right away.
    let isReadyForTips: Bool
    /// Shows the sidebar, where the tour starts.
    let onStartTour: () -> Void

    @State private var sessionReadAtReadingTip: String?

    /// How long the sidebar gets to draw what was found, so the tour starts on it.
    static let tourStartDelay: Duration = .milliseconds(600)
    /// How long the window stays as it is before a tip shows, so none flashes while sessions or tabs are switched.
    static let tipDelay: Duration = .seconds(1)

    private struct FirstLaunchTourTrigger: Equatable {
        let hasListedThisMac: Bool
        let isReadyForTips: Bool
    }

    private struct TipTrigger: Equatable {
        let windowContext: OnboardingWindowContext
        let isTourRunning: Bool
        let isReadyForTips: Bool
    }

    private struct CurrentStopInContext: Equatable {
        let currentStopIndex: Int?
        let windowContext: OnboardingWindowContext
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

    private var windowContext: OnboardingWindowContext {
        OnboardingWindowContext(
            readSessionID: readSession?.id,
            canResumeReadSession: readSession.map { store.canLaunch($0, action: .resume) } ?? false,
            sessionReadAtReadingTip: sessionReadAtReadingTip,
            hasSelectedTab: store.selectedTerminal != nil,
            selectedTabCanKeepRunning: selectedTabCanKeepRunning,
            openTabCount: store.terminalSessions.count,
            isSidebarShown: isSidebarShown
        )
    }

    func body(content: Content) -> some View {
        let windowContext = windowContext
        content
            .environment(\.onboardingTour, tour)
            .environment(\.startOnboardingTour, StartOnboardingTourAction(start: startTour))
            .focusedSceneValue(\.startOnboardingTour, isReadyForTips ? StartOnboardingTourAction(start: startTour) : nil)
            .task(id: FirstLaunchTourTrigger(hasListedThisMac: hasListedThisMac, isReadyForTips: isReadyForTips)) {
                await startTourAtFirstLaunch()
            }
            .task(id: TipTrigger(windowContext: windowContext, isTourRunning: tour.isRunning, isReadyForTips: isReadyForTips)) {
                await showDueTips()
            }
            .onChange(of: CurrentStopInContext(currentStopIndex: tour.currentStopIndex, windowContext: windowContext)) { _, current in
                tour.moveOnFromStops { $0.canShow(in: current.windowContext) }
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

    /// Shows the tips due once the window has stayed as it is for `tipDelay`, one after another when several are.
    private func showDueTips() async {
        guard isReadyForTips, !tour.isRunning,
              !OnboardingTip.due(in: windowContext, among: tipsStore.tipsToShow).isEmpty else { return }
        do { try await Task.sleep(for: Self.tipDelay) } catch { return }
        // Read again, as another workspace window may have shown some meanwhile.
        let windowContext = windowContext
        let dueTips = OnboardingTip.due(in: windowContext, among: tipsStore.tipsToShow)
        guard !dueTips.isEmpty else { return }
        for dueTip in dueTips {
            tipsStore.markShown(dueTip.tip)
            if dueTip.tip == .readingSession { sessionReadAtReadingTip = windowContext.readSessionID }
        }
        tour.start(dueTips.flatMap(\.stops))
    }
}
