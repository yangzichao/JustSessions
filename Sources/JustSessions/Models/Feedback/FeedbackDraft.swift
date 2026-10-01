import Foundation

/// Only the user's text and optional version information enter the report.
struct FeedbackDraft {
    var kind: FeedbackKind = .bug
    var title = ""
    var details = ""
    var includesVersionInformation = true

    var canContinue: Bool {
        !trimmedTitle.isEmpty && trimmedTitle.count <= 200 && !trimmedDetails.isEmpty
    }

    var issueTitle: String { "[\(kind.titlePrefix)] \(trimmedTitle)" }

    func reportBody(versionInformation: String) -> String {
        var body = "## \(kind.rawValue)\n\n\(trimmedDetails)"
        if includesVersionInformation {
            body += "\n\n## Environment\n\n\(versionInformation)"
        }
        return body
    }

    func copyableReport(versionInformation: String) -> String {
        "# \(issueTitle)\n\n\(reportBody(versionInformation: versionInformation))"
    }

    /// Large reports are copied instead of risking truncation in a browser URL.
    func prefilledIssueURL(versionInformation: String) -> URL? {
        guard canContinue else { return nil }
        let url = issueURL(body: reportBody(versionInformation: versionInformation))
        return url.absoluteString.utf8.count <= 7_000 ? url : nil
    }

    var titleOnlyIssueURL: URL { issueURL(body: nil) }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDetails: String { details.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func issueURL(body: String?) -> URL {
        var components = URLComponents(url: AppLinks.newFeedbackIssueURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "title", value: issueTitle)]
        if let body { components.queryItems?.append(URLQueryItem(name: "body", value: body)) }
        // GitHub decodes query strings as form data, where a literal plus otherwise becomes a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }
}
