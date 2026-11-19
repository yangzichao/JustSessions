import Combine

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

    func showNextStop() {
        guard let currentStopIndex else { return }
        if currentStopIndex + 1 < stops.count {
            self.currentStopIndex = currentStopIndex + 1
        } else {
            end()
        }
    }

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
