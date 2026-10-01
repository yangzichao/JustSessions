import Foundation
import Testing
@testable import JustSessions

struct FeedbackDraftTests {
    @Test func blankOrOverlongFeedbackCannotContinue() {
        var draft = FeedbackDraft(title: " \n", details: "Details")
        #expect(!draft.canContinue)
        draft.title = "Summary"
        draft.details = " \n"
        #expect(!draft.canContinue)
        draft.details = "Details"
        draft.title = String(repeating: "a", count: 201)
        #expect(!draft.canContinue)
        draft.title = String(repeating: "a", count: 200)
        #expect(draft.canContinue)
    }

    @Test func queryPreservesUnicodeAndReservedCharacters() throws {
        let draft = FeedbackDraft(kind: .feature, title: "  中文 & + # idea 🚀  ", details: "Line one & labels=bug\nLine two + # ? 🚀")
        let url = try #require(draft.prefilledIssueURL(versionInformation: "App: 1.0\nmacOS: 14.0"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: try #require(components.queryItems).map { ($0.name, $0.value ?? "") })
        #expect(url.host == "github.com")
        #expect(url.path == "/yangzichao/JustSessions/issues/new")
        #expect(!url.absoluteString.contains("+"))
        #expect(query["title"] == "[Feature] 中文 & + # idea 🚀")
        #expect(query["body"] == "## Feature request\n\nLine one & labels=bug\nLine two + # ? 🚀\n\n## Environment\n\nApp: 1.0\nmacOS: 14.0")
        #expect(query.count == 2)
    }

    @Test func versionInformationCanBeExcluded() {
        let draft = FeedbackDraft(title: "Summary", details: "Details", includesVersionInformation: false)
        #expect(draft.reportBody(versionInformation: "App: secret-version") == "## Bug report\n\nDetails")
        #expect(!draft.copyableReport(versionInformation: "App: secret-version").contains("secret-version"))
    }

    @Test func longReportsKeepTheirFullContentForCopying() throws {
        let details = String(repeating: "长报告 🚀\n", count: 2_000)
        let draft = FeedbackDraft(title: "Long report", details: details)
        #expect(draft.canContinue)
        #expect(draft.prefilledIssueURL(versionInformation: "App: 1.0") == nil)
        #expect(draft.copyableReport(versionInformation: "App: 1.0").contains(details.trimmingCharacters(in: .whitespacesAndNewlines)))
        let query = try #require(URLComponents(url: draft.titleOnlyIssueURL, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(query == [URLQueryItem(name: "title", value: "[Bug] Long report")])
    }
}
