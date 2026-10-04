import Testing
@testable import JustSessions

@MainActor
struct OnboardingTourTests {
    @Test func walksItsStopsInOrderAndEndsAfterTheLast() {
        let tour = OnboardingTour()
        tour.start([.newSession, .sshHosts])
        #expect(tour.currentStop == .newSession)
        #expect(tour.isRunning)

        tour.showNextStop()
        #expect(tour.currentStop == .sshHosts)
        #expect(tour.currentStopIndex == 1)

        tour.showNextStop()
        #expect(tour.currentStop == nil)
        #expect(!tour.isRunning)
        #expect(tour.stops.isEmpty)
    }

    @Test func skippingEndsTheTourAtAnyStop() {
        let tour = OnboardingTour()
        tour.start([.projects, .sessions, .newSession])

        tour.end()

        #expect(!tour.isRunning)
        tour.showNextStop()
        #expect(!tour.isRunning)
    }

    @Test func startingWithNoStopsLeavesTheTourAsItWas() {
        let tour = OnboardingTour()
        tour.start([])
        #expect(!tour.isRunning)

        tour.start([.keepRunning])
        tour.start([])
        #expect(tour.currentStop == .keepRunning)
    }
}
