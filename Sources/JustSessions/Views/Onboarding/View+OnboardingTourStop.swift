import SwiftUI

extension View {
    func onboardingTourStop(_ stop: OnboardingTourStop?) -> some View {
        modifier(OnboardingTourStopModifier(stop: stop))
    }

    func onOnboardingTourStop(_ onShowStop: @escaping (OnboardingTourStop) -> Void) -> some View {
        modifier(OnboardingTourStopObserver(onShowStop: onShowStop))
    }
}

private struct OnboardingTourStopModifier: ViewModifier {
    let stop: OnboardingTourStop?
    @Environment(\.onboardingTour) private var tour

    func body(content: Content) -> some View {
        content.background {
            if let stop, let tour {
                OnboardingTourStopTip(stop: stop, tour: tour)
            }
        }
    }
}

private struct OnboardingTourStopTip: View {
    let stop: OnboardingTourStop
    @ObservedObject var tour: OnboardingTour
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        OnboardingTourPopoverAnchor(card: isEnabled ? card : nil, edge: stop.tipEdge)
    }

    private var card: OnboardingTourCard? {
        guard let currentStopIndex = tour.currentStopIndex, tour.currentStop == stop else { return nil }
        return OnboardingTourCard(
            stop: stop,
            stepNumber: currentStopIndex + 1,
            stepCount: tour.stops.count,
            onNext: tour.showNextStop,
            onEnd: tour.end
        )
    }
}

private struct OnboardingTourStopObserver: ViewModifier {
    let onShowStop: (OnboardingTourStop) -> Void
    @Environment(\.onboardingTour) private var tour

    func body(content: Content) -> some View {
        content.background {
            if let tour {
                OnboardingTourStopChanges(tour: tour, onShowStop: onShowStop)
            }
        }
    }
}

private struct OnboardingTourStopChanges: View {
    @ObservedObject var tour: OnboardingTour
    let onShowStop: (OnboardingTourStop) -> Void

    var body: some View {
        Color.clear
            .onChange(of: tour.currentStop, initial: true) { _, stop in
                if let stop { onShowStop(stop) }
            }
    }
}
