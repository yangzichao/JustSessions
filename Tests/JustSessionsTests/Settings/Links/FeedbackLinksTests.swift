import Foundation
import Testing
@testable import JustSessions

struct FeedbackLinksTests {
    private let environment = FeedbackEnvironment(appVersion: "0.45.0 (45)", macOSVersion: "26.0.1")

    private func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    @Test func gitHubIssueStartsWithTheVersionsBelowRoomToWrite() throws {
        let url = FeedbackLinks.gitHubIssueURL(for: environment)
        #expect(url.absoluteString.hasPrefix("https://github.com/yangzichao/JustSessions/issues/new?body="))
        #expect(queryValue("body", in: url) == "\n\nJustSessions 0.45.0 (45) · macOS 26.0.1")
    }

    @Test func emailHasTheSubjectAndTheVersions() throws {
        let url = FeedbackLinks.emailURL(for: environment)
        #expect(url.scheme == "mailto")
        #expect(url.absoluteString.hasPrefix("mailto:zichaoyangphys@gmail.com?"))
        #expect(queryValue("subject", in: url) == "JustSessions feedback")
        #expect(queryValue("body", in: url) == "\n\nJustSessions 0.45.0 (45) · macOS 26.0.1")
        // Mail clients read %20 as a space but may show a + as is.
        #expect(!url.absoluteString.contains("+"))
    }

    @Test func userGuideSectionLinksPointAtSectionsTheGuideHas() throws {
        let guide = try RepositoryFiles.contents(of: "website/guide.html")
        for url in [AppLinks.userGuideSSHHostsURL, AppLinks.userGuideTroubleshootingURL] {
            #expect(url.absoluteString.hasPrefix(AppLinks.userGuideURL.absoluteString + "#"))
            let sectionID = try #require(url.fragment)
            #expect(guide.contains("id=\"\(sectionID)\""))
        }
    }
}
