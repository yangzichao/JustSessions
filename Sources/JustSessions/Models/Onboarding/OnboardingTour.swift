import Combine

/// The onboarding stops showing in one workspace window, the tour's or a tip's, and the one whose tip shows. A tip's
/// buttons move it on, so you can try what a tip points at while it shows; so does that control going out of use.
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

    /// Moves past the current stop, and those after it, while they can't show; ends the tour if none after can.
    func moveOnFromStops(thatCannotShow canShow: (OnboardingTourStop) -> Bool) {
        while let currentStop, !canShow(currentStop) {
            showNextStop()
        }
    }

    func end() {
        currentStopIndex = nil
        stops = []
    }
}
