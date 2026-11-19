import Testing

@testable import JustSessions

struct ProjectSessionRowLimitsTests {
    @Test func aProjectStartsWithTheFirstSessions() {
        #expect(ProjectSessionRowLimits().sessionLimit(inProject: "a") == ProjectSessionRowLimits.initialSessionCount)
    }

    @Test func showMoreListsTheNextBatch() {
        var limits = ProjectSessionRowLimits()

        limits.showMore(inProject: "a", hiddenSessionCount: 100)

        #expect(limits.sessionLimit(inProject: "a") == 10 + 20)
        #expect(limits.sessionLimit(inProject: "b") == 10, "Each project keeps its own")
    }

    @Test func showMoreListsEveryHiddenSessionWhenTheBatchWouldLeaveOne() {
        #expect(ProjectSessionRowLimits.sessionsShownByShowMore(hiddenSessionCount: 22) == 20)
        #expect(ProjectSessionRowLimits.sessionsShownByShowMore(hiddenSessionCount: 21) == 21)
        #expect(ProjectSessionRowLimits.sessionsShownByShowMore(hiddenSessionCount: 5) == 5)

        var limits = ProjectSessionRowLimits()
        limits.showMore(inProject: "a", hiddenSessionCount: 21)
        #expect(ProjectSessionRowLimits.listedSessionCount(of: 31, limit: limits.sessionLimit(inProject: "a")) == 31)
    }

    @Test func revealingAHiddenSessionListsDownToIt() {
        var limits = ProjectSessionRowLimits()

        limits.reveal(sessionAt: 42, inProject: "a")
        #expect(limits.sessionLimit(inProject: "a") == 43)

        limits.reveal(sessionAt: 5, inProject: "a")
        #expect(limits.sessionLimit(inProject: "a") == 43, "Revealing a listed session never lists fewer")
    }

    @Test func resettingGoesBackToTheFirstSessions() {
        var limits = ProjectSessionRowLimits()
        limits.showMore(inProject: "a", hiddenSessionCount: 100)

        limits.reset("a")

        #expect(limits.sessionLimit(inProject: "a") == ProjectSessionRowLimits.initialSessionCount)
    }
}
