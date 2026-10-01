import Foundation

enum AppLinks {
    static let githubRepositoryURL = URL(string: "https://github.com/yangzichao/JustSessions")!
    static let githubIssuesURL = githubRepositoryURL.appendingPathComponent("issues")
    static let newFeedbackIssueURL = githubIssuesURL.appendingPathComponent("new")
}
