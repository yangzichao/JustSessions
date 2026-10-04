import Testing
@testable import JustSessions

struct OnboardingTourStopTests {
    @Test func tourPointsAtAProjectAndItsSessionsOnceThisMacListsOne() {
        #expect(
            OnboardingTourStop.tour(listsProjectWithSessions: true, selectedTabCanKeepRunning: false)
                == [.projects, .sessions, .newSession, .sshHosts]
        )
    }

    @Test func tourExplainsTheEmptyListWhenThisMacHasNoSessions() {
        #expect(
            OnboardingTourStop.tour(listsProjectWithSessions: false, selectedTabCanKeepRunning: false)
                == [.noSessionsYet, .newSession, .sshHosts]
        )
    }

    @Test func tourEndsAtKeepRunningWhenTheSelectedTabCanKeepRunning() {
        #expect(
            OnboardingTourStop.tour(listsProjectWithSessions: true, selectedTabCanKeepRunning: true).last
                == .keepRunning
        )
    }

    @Test func onlyProjectListStopsNeedTheProjectList() {
        let projectListStops = OnboardingTourStop.allCases.filter(\.isInProjectList)
        #expect(projectListStops == [.noSessionsYet, .projects, .sessions])
    }
}
