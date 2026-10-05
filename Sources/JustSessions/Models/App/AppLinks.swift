import Foundation

enum AppLinks {
    static let websiteURL = URL(string: "https://yangzichao.github.io/JustSessions/")!
    static let userGuideURL = websiteURL.appendingPathComponent("guide.html")
    static let userGuideSSHHostsURL = userGuideSection("ssh-hosts")
    static let userGuideTroubleshootingURL = userGuideSection("troubleshooting")
    static let gitHubRepositoryURL = URL(string: "https://github.com/yangzichao/JustSessions")!
    static let newGitHubIssueURL = gitHubRepositoryURL.appendingPathComponent("issues/new")
    static let feedbackEmailAddress = "zichaoyangphys@gmail.com"

    /// The user guide at one of its sections, by the section's id in `website/guide.html`.
    private static func userGuideSection(_ sectionID: String) -> URL {
        var components = URLComponents(url: userGuideURL, resolvingAgainstBaseURL: false)!
        components.fragment = sectionID
        return components.url!
    }
}
