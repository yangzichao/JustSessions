import Foundation

/// How many of each project's sessions the sidebar lists before a "Show N more" row, counting only the sessions that
/// are not pinned; pinned sessions and new sessions' tabs are always listed. Each window keeps its own limits. A project
/// starts at `initialSessionCount` and goes back to it when it collapses.
struct ProjectSessionRowLimits: Equatable {
    /// The sessions an expanded project lists at first, after its pinned and new sessions.
    static let initialSessionCount = 10
    /// How many more sessions each "Show N more" lists.
    static let sessionsPerShowMore = 20

    private var sessionLimitByProjectID: [String: Int] = [:]

    func sessionLimit(inProject projectID: String) -> Int {
        sessionLimitByProjectID[projectID] ?? Self.initialSessionCount
    }

    /// How many of `sessionCount` sessions are listed under `limit`, or all of them without one. A single session past
    /// the limit is listed too, since a "Show 1 more" row would take the room of the session it hides.
    static func listedSessionCount(of sessionCount: Int, limit: Int?) -> Int {
        guard let limit, sessionCount > limit + 1 else { return sessionCount }
        return max(limit, 0)
    }

    /// How many sessions "Show N more" lists while `hiddenSessionCount` are hidden: the next batch, or all of them when
    /// the batch would leave just one hidden.
    static func sessionsShownByShowMore(hiddenSessionCount: Int) -> Int {
        hiddenSessionCount > sessionsPerShowMore + 1 ? sessionsPerShowMore : hiddenSessionCount
    }

    mutating func showMore(inProject projectID: String, hiddenSessionCount: Int) {
        sessionLimitByProjectID[projectID] =
            sessionLimit(inProject: projectID)
            + Self.sessionsShownByShowMore(hiddenSessionCount: hiddenSessionCount)
    }

    /// Lists the project's sessions down to the one at `index` among those the limit counts, so a session shown by
    /// other means, such as Back or a notification, has its row in sight.
    mutating func reveal(sessionAt index: Int, inProject projectID: String) {
        guard index >= sessionLimit(inProject: projectID) else { return }
        sessionLimitByProjectID[projectID] = index + 1
    }

    /// Back to `initialSessionCount`, as when the project collapses.
    mutating func reset(_ projectID: String) {
        sessionLimitByProjectID[projectID] = nil
    }
}
