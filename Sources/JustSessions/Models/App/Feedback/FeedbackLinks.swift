import Foundation

/// Where General sends feedback: the website's feedback form or a new GitHub issue, each started with the versions it
/// is about.
enum FeedbackLinks {
    /// The Guide's feedback form, which shows these versions and sends them with the message.
    static func formURL(for environment: FeedbackEnvironment) -> URL {
        var components = URLComponents(url: AppLinks.userGuideFeedbackURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "appVersion", value: environment.appVersion),
            URLQueryItem(name: "macOSVersion", value: environment.macOSVersion),
        ]
        return components.url!
    }

    /// Two empty lines to write in, then the versions.
    static func gitHubIssueURL(for environment: FeedbackEnvironment) -> URL {
        var components = URLComponents(url: AppLinks.newGitHubIssueURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "body", value: "\n\n\(environment.summary)")]
        return components.url!
    }
}
