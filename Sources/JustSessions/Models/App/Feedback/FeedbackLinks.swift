import Foundation

/// Where Help sends feedback: a new GitHub issue or an email, each started with the versions it is about, below the
/// space for the report itself.
enum FeedbackLinks {
    static func gitHubIssueURL(for environment: FeedbackEnvironment) -> URL {
        var components = URLComponents(url: AppLinks.newGitHubIssueURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "body", value: reportBody(for: environment))]
        return components.url!
    }

    static func emailURL(for environment: FeedbackEnvironment) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppLinks.feedbackEmailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: "JustSessions feedback"),
            URLQueryItem(name: "body", value: reportBody(for: environment)),
        ]
        return components.url!
    }

    /// Two empty lines to write in, then the versions.
    private static func reportBody(for environment: FeedbackEnvironment) -> String {
        "\n\n\(environment.summary)"
    }
}
