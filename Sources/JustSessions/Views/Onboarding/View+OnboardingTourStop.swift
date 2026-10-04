import SwiftUI

extension View {
    /// Shows the window's tour tip on this view while the tour is at `stop`. Nil makes it no stop, so one row of a
    /// list can be the stop without the others changing.
    func onboardingTourStop(_ stop: OnboardingTourStop?) -> some View {
        modifier(OnboardingTourStopModifier(stop: stop))
    }

    /// Calls `onShowStop` each time the window's tour moves to a stop, so a view can bring that stop into sight.
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

/// The tip while the tour is at `stop`. The sidebar list hidden behind Open tabs is disabled, so a tip in it waits
/// until the list shows again.
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
