import Foundation

enum FeedbackLinks {
    static func formURL(for environment: FeedbackEnvironment) -> URL {
        var components = URLComponents(url: AppLinks.userGuideFeedbackURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "appVersion", value: environment.appVersion),
            URLQueryItem(name: "macOSVersion", value: environment.macOSVersion),
        ]
        return components.url!
    }

    static func gitHubIssueURL(for environment: FeedbackEnvironment) -> URL {
        var components = URLComponents(url: AppLinks.newGitHubIssueURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "body", value: "\n\n\(environment.summary)")]
        return components.url!
    }
}
