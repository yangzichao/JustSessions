import SwiftUI

extension EnvironmentValues {
    @Entry var onboardingTour: OnboardingTour?
    @Entry var startOnboardingTour = StartOnboardingTourAction {}
}

struct StartOnboardingTourAction {
    let start: @MainActor () -> Void

    @MainActor func callAsFunction() {
        start()
    }
}
