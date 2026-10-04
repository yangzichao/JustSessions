import Foundation

enum AppLinks {
    static let websiteURL = URL(string: "https://yangzichao.github.io/JustSessions/")!
    static let userGuideURL = websiteURL.appendingPathComponent("guide.html")
    static let createGitHubIssueURL = URL(string: "https://github.com/yangzichao/JustSessions/issues/new")!
    static let feedbackEmailURL = URL(string: "mailto:zichaoyangphys@gmail.com?subject=JustSessions%20feedback")!
}
