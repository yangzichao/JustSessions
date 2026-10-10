import Foundation
import SwiftUI
import Testing
@testable import JustSessions

struct FeedbackVerificationPageTests {
    private func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    @Test func thePageMatchesTheAppsAppearanceAndLanguage() {
        let darkChinese = FeedbackVerificationPage.url(colorScheme: .dark, locale: Locale(identifier: "zh-Hans"))
        #expect(darkChinese.absoluteString.hasPrefix("https://yangzichao.github.io/JustSessions/app-feedback-verification.html?"))
        #expect(queryValue("theme", in: darkChinese) == "dark")
        #expect(queryValue("language", in: darkChinese) == "zh-Hans")

        let lightEnglish = FeedbackVerificationPage.url(colorScheme: .light, locale: Locale(identifier: "en"))
        #expect(queryValue("theme", in: lightEnglish) == "light")
        #expect(queryValue("language", in: lightEnglish) == "en")
    }

    @Test func theMainFrameStaysOnThePageAndFollowedLinksOpenInTheBrowser() {
        let page = FeedbackVerificationPage.url(colorScheme: .light, locale: Locale(identifier: "en"))
        #expect(FeedbackVerificationPage.navigationDecision(for: page, inMainFrame: true, followsLink: false) == .allow)
        let privacy = URL(string: "https://www.cloudflare.com/privacypolicy/")!
        #expect(FeedbackVerificationPage.navigationDecision(for: privacy, inMainFrame: true, followsLink: true) == .openInBrowser)
        #expect(FeedbackVerificationPage.navigationDecision(for: privacy, inMainFrame: true, followsLink: false) == .cancel)
        let guide = URL(string: "https://yangzichao.github.io/JustSessions/guide.html")!
        #expect(FeedbackVerificationPage.navigationDecision(for: guide, inMainFrame: true, followsLink: false) == .cancel)
        let insecure = URL(string: "http://example.com/")!
        #expect(FeedbackVerificationPage.navigationDecision(for: insecure, inMainFrame: true, followsLink: true) == .cancel)
        #expect(FeedbackVerificationPage.navigationDecision(for: nil, inMainFrame: true, followsLink: true) == .cancel)
    }

    @Test func framesMayLoadOnlyTurnstilesChallenge() {
        for (address, decision) in [
            ("https://challenges.cloudflare.com/cdn-cgi/challenge-platform/h/b/turnstile/if/ov2/av0/rcv/abc", FeedbackVerificationPage.NavigationDecision.allow),
            ("about:blank", .allow),
            ("about:srcdoc", .allow),
            ("http://challenges.cloudflare.com/", .cancel),
            ("https://challenges.cloudflare.com.example/", .cancel),
            ("https://example.com/", .cancel),
        ] {
            #expect(FeedbackVerificationPage.navigationDecision(for: URL(string: address), inMainFrame: false, followsLink: false) == decision, "\(address)")
        }
    }

    @Test func thePageReportsTokensExpiryAndErrorsOnly() {
        #expect(TurnstileVerificationEvent(messageBody: ["event": "verified", "token": "abc"]) == .verified(token: "abc"))
        #expect(TurnstileVerificationEvent(messageBody: ["event": "expired"]) == .expired)
        #expect(TurnstileVerificationEvent(messageBody: ["event": "error"]) == .failed)
        for body: Any in [
            ["event": "verified"],
            ["event": "verified", "token": ""],
            ["event": "verified", "token": String(repeating: "a", count: 2049)],
            ["event": "send", "message": "Hi"],
            "verified",
        ] {
            #expect(TurnstileVerificationEvent(messageBody: body) == nil)
        }
    }
}
