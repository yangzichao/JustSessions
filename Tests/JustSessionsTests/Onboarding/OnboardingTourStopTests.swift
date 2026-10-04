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

    @Test func onlyTheTourStopsInTheProjectListBringItsProjectIntoSight() {
        let projectListStops = OnboardingTourStop.allCases.filter(\.isTourStopInProjectList)
        #expect(projectListStops == [.noSessionsYet, .projects, .sessions])
    }

    @Test func conversationStopsCanShowOnlyWhileAConversationShows() {
        let reading = OnboardingWindowContext(readSessionID: "claude:1")
        let tabInFront = OnboardingWindowContext(hasSelectedTab: true)
        for stop in [OnboardingTourStop.resume, .findInConversation, .sessionMenu] {
            #expect(stop.canShow(in: reading))
            #expect(!stop.canShow(in: tabInFront))
        }
    }

    @Test func sidebarStopsCannotShowWhileTheSidebarIsHidden() {
        let sidebarHidden = OnboardingWindowContext(readSessionID: "claude:1", hasSelectedTab: true, openTabCount: 2, isSidebarShown: false)
        for stop in [OnboardingTourStop.sessionMenu, .searchSessions, .hideSidebar, .openTabs] {
            #expect(!stop.canShow(in: sidebarHidden))
        }
        #expect(OnboardingTourStop.tabGroup.canShow(in: sidebarHidden))
    }

    @Test func tourStopsAmongTheProjectsCanAlwaysShow() {
        let emptyWindow = OnboardingWindowContext(isSidebarShown: false)
        for stop in [OnboardingTourStop.noSessionsYet, .projects, .sessions, .newSession, .sshHosts] {
            #expect(stop.canShow(in: emptyWindow))
        }
    }
}
