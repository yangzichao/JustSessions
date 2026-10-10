import Foundation

enum AppLinks {
    static let websiteURL = URL(string: "https://yangzichao.github.io/JustSessions/")!
    static let userGuideURL = websiteURL.appendingPathComponent("guide.html")
    static let releaseNotesURL = websiteURL.appendingPathComponent("release-notes.html")
    static let userGuideSSHHostsURL = userGuideSection("ssh-hosts")
    static let userGuideSSHShellStartupURL = userGuideSection("ssh-shell-startup")
    static let userGuideTroubleshootingURL = userGuideSection("troubleshooting")
    static let gitHubRepositoryURL = URL(string: "https://github.com/yangzichao/JustSessions")!
    static let newGitHubIssueURL = gitHubRepositoryURL.appendingPathComponent("issues/new")
    static let feedbackEmailAddress = "zichaoyangphys@gmail.com"
    /// The Worker in `Cloudflare/Feedback` that stores feedback sent from Settings.
    static let feedbackEndpointURL = URL(string: "https://justsessions-feedback.noether-lab.workers.dev/feedback")!
    /// The page that runs Cloudflare Turnstile for that feedback, in `website/app-feedback-verification.html`.
    static let feedbackVerificationPageURL = websiteURL.appendingPathComponent("app-feedback-verification.html")

    /// The user guide at one of its sections, by the section's id in `website/guide.html`.
    private static func userGuideSection(_ sectionID: String) -> URL {
        var components = URLComponents(url: userGuideURL, resolvingAgainstBaseURL: false)!
        components.fragment = sectionID
        return components.url!
    }
}
