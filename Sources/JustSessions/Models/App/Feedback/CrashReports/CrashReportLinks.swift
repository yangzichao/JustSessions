import Foundation

/// A crash as a new GitHub issue on the bug report form, or as an email, with the crash's versions and summary filled
/// in, for the person to add what they were doing before sending it. The text stays in English: it is for the
/// maintainers, like the crash report itself.
enum CrashReportLinks {
    /// The details are cut to this many characters, last frames first, so the issue's link stays well within the
    /// length GitHub accepts. The whole crash report can be attached.
    static let maximumDetailsLength = 2_500
    static let bugReportTemplate = "bug_report.yml"

    /// Fills the bug report form's fields by their ids in `.github/ISSUE_TEMPLATE/bug_report.yml`.
    static func gitHubIssueURL(for summary: CrashReportSummary, reportFileName: String) -> URL {
        var components = URLComponents(url: AppLinks.newGitHubIssueURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "template", value: bugReportTemplate),
            URLQueryItem(name: "title", value: title(for: summary)),
            URLQueryItem(name: "app-version", value: summary.appVersion),
            URLQueryItem(name: "macos-version", value: summary.macOSVersion),
            URLQueryItem(name: "actual-behavior", value: "JustSessions quit unexpectedly."),
            URLQueryItem(name: "supporting-details", value: details(of: summary, reportFileName: reportFileName)),
        ]
        return withPlusSignsEncoded(components).url!
    }

    static func emailURL(for summary: CrashReportSummary, reportFileName: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppLinks.feedbackEmailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: title(for: summary)),
            URLQueryItem(name: "body", value: """
                What I was doing when it quit:



                JustSessions \(summary.appVersion) · \(summary.macOSVersion)

                \(details(of: summary, reportFileName: reportFileName))
                """),
        ]
        return withPlusSignsEncoded(components).url!
    }

    /// Such as "Crash: EXC_BREAKPOINT (SIGTRAP) in JustSessions 1.0.5 (12)".
    static func title(for summary: CrashReportSummary) -> String {
        "Crash: \(summary.exception ?? "unknown exception") in JustSessions \(summary.appVersion)"
    }

    /// The report's file name, then the exception, the crashing libraries' messages, and the backtraces in a code
    /// block. An Objective-C exception's own backtrace comes first: the crashed thread then only rethrows it.
    static func details(of summary: CrashReportSummary, reportFileName: String) -> String {
        var lines = ["Exception: \(summary.exception ?? "unknown")"] + summary.crashMessages
        if !summary.lastExceptionFrames.isEmpty {
            lines += ["", "Last exception backtrace:"] + summary.lastExceptionFrames
        }
        if !summary.crashedThreadFrames.isEmpty {
            lines += ["", "Crashed thread\(summary.crashedThreadQueue.map { " (\($0))" } ?? ""):"] + summary.crashedThreadFrames
        }
        let heading = "Crash report \(reportFileName), in ~/Library/Logs/DiagnosticReports"
        func text(of lines: [String]) -> String {
            "\(heading)\n\n```\n\(lines.joined(separator: "\n"))\n```"
        }
        var isCut = false
        while lines.count > 1, text(of: lines + (isCut ? ["…"] : [])).count > maximumDetailsLength {
            lines.removeLast()
            isCut = true
        }
        return text(of: lines + (isCut ? ["…"] : []))
    }

    /// `URLComponents` leaves `+` in a query as it is, and GitHub reads it as a space, as in C++ symbols.
    private static func withPlusSignsEncoded(_ components: URLComponents) -> URLComponents {
        var components = components
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components
    }
}
