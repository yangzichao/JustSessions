import SwiftUI

struct OnboardingTipsPresenter: ViewModifier {
    let store: ConversationStore
    @ObservedObject var tour: OnboardingTour
    let tipsStore: OnboardingTipsStore
    let listsProjectWithSessions: Bool
    let focusedConversation: Conversation?
    let isSidebarShown: Bool
    let isReadyForTips: Bool
    let onStartTour: () -> Void

    @State private var sessionReadAtReadingTip: String?

    static let tourStartDelay: Duration = .milliseconds(600)
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

    private var readSession: Conversation? {
        store.selectedTerminalID == nil ? focusedConversation : nil
    }

    private var selectedTabCanKeepRunning: Bool {
        store.selectedTerminal?.canKeepCLIRunningAfterClose == true
    }

    private var isSelectedTabInSplit: Bool {
        store.selectedTerminalID.map { store.split(containing: $0) != nil } ?? false
    }

    private var windowContext: OnboardingWindowContext {
        OnboardingWindowContext(
            readSessionID: readSession?.id,
            canResumeReadSession: readSession.map { store.canLaunch($0, action: .resume) } ?? false,
            sessionReadAtReadingTip: sessionReadAtReadingTip,
            hasSelectedTab: store.selectedTerminal != nil,
            selectedTabCanKeepRunning: selectedTabCanKeepRunning,
            isSelectedTabInSplit: isSelectedTabInSplit,
            openTabCount: store.terminalSessions.count,
            isSidebarShown: isSidebarShown
        )
    }

    func body(content: Content) -> some View {
        let windowContext = windowContext
        content
            .environment(\.onboardingTour, tour)
            .environment(\.startOnboardingTour, StartOnboardingTourAction(start: restartTour))
            .focusedSceneValue(\.startOnboardingTour, isReadyForTips ? StartOnboardingTourAction(start: restartTour) : nil)
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
        guard tipsStore.shouldShow(.tour) else { return }
        startTour()
    }

    private func restartTour() {
        tipsStore.showEveryTipAgain()
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

    private func showDueTips() async {
        guard isReadyForTips, !tour.isRunning,
            !OnboardingTip.due(in: windowContext, among: tipsStore.tipsToShow).isEmpty
        else { return }
        do { try await Task.sleep(for: Self.tipDelay) } catch { return }
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
