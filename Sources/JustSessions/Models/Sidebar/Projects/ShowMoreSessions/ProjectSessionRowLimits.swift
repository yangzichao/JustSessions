import Foundation

struct ProjectSessionRowLimits: Equatable {
    static let initialSessionCount = 10
    static let sessionsPerShowMore = 20

    private var sessionLimitByProjectID: [String: Int] = [:]

    func sessionLimit(inProject projectID: String) -> Int {
        sessionLimitByProjectID[projectID] ?? Self.initialSessionCount
    }

    static func listedSessionCount(of sessionCount: Int, limit: Int?) -> Int {
        guard let limit, sessionCount > limit + 1 else { return sessionCount }
        return max(limit, 0)
    }

    static func sessionsShownByShowMore(hiddenSessionCount: Int) -> Int {
        hiddenSessionCount > sessionsPerShowMore + 1 ? sessionsPerShowMore : hiddenSessionCount
    }

    mutating func showMore(inProject projectID: String, hiddenSessionCount: Int) {
        sessionLimitByProjectID[projectID] =
            sessionLimit(inProject: projectID)
            + Self.sessionsShownByShowMore(hiddenSessionCount: hiddenSessionCount)
    }

    mutating func reveal(sessionAt index: Int, inProject projectID: String) {
        guard index >= sessionLimit(inProject: projectID) else { return }
        sessionLimitByProjectID[projectID] = index + 1
    }

    mutating func reset(_ projectID: String) {
        sessionLimitByProjectID[projectID] = nil
    }
}
