import Combine

/// The onboarding tour of one workspace window: its stops, and the one whose tip shows. Only a tip's buttons move it
/// on, so you can try what a tip points at while it shows.
@MainActor
final class OnboardingTour: ObservableObject {
    @Published private(set) var stops: [OnboardingTourStop] = []
    @Published private(set) var currentStopIndex: Int?

    var currentStop: OnboardingTourStop? {
        currentStopIndex.map { stops[$0] }
    }

    var isRunning: Bool {
        currentStopIndex != nil
    }

    func start(_ stops: [OnboardingTourStop]) {
        guard !stops.isEmpty else { return }
        self.stops = stops
        currentStopIndex = 0
    }

    /// Shows the next stop's tip, or ends the tour after its last.
    func showNextStop() {
        guard let currentStopIndex else { return }
        if currentStopIndex + 1 < stops.count {
            self.currentStopIndex = currentStopIndex + 1
        } else {
            end()
        }
    }

    func end() {
        currentStopIndex = nil
        stops = []
    }
}
