import SwiftUI

extension EnvironmentValues {
    /// The onboarding tour of the workspace window a view is in; nil outside one.
    @Entry var onboardingTour: OnboardingTour?
    /// Starts that window's tour from its first stop, as Help does.
    @Entry var startOnboardingTour = StartOnboardingTourAction {}
}

/// Starts the onboarding tour of the workspace window this view is in.
struct StartOnboardingTourAction {
    let start: @MainActor () -> Void

    @MainActor func callAsFunction() {
        start()
    }
}
