import SwiftUI

struct SidebarRandomTip: View {
    @Environment(\.onboardingTour) private var onboardingTour

    var body: some View {
        if let onboardingTour {
            SidebarRandomTipSlot(tipsStore: .shared, onboardingTour: onboardingTour)
        }
    }
}

private struct SidebarRandomTipSlot: View {
    @ObservedObject var tipsStore: RandomTipsStore
    @ObservedObject var onboardingTour: OnboardingTour

    private var shownTip: RandomTip? {
        onboardingTour.isRunning ? nil : tipsStore.currentTip
    }

    var body: some View {
        VStack(spacing: 0) {
            if let shownTip {
                RandomTipCard(
                    tip: shownTip,
                    onShowNextTip: tipsStore.showNextTip,
                    onHide: tipsStore.hideUntilNextLaunch,
                    onTurnOffTips: { tipsStore.setShowsTips(false) }
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .animation(ThemeMotion.slide, value: shownTip)
    }
}
