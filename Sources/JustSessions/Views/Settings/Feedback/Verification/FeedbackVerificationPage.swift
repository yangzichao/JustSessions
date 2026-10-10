import SwiftUI

/// The published page that runs Cloudflare Turnstile for the app's feedback, and what its web view may load: that
/// page, and Turnstile's challenge frames from Cloudflare. A link the visitor follows, such as Turnstile's privacy
/// notice, opens in the browser.
enum FeedbackVerificationPage {
    static let turnstileHost = "challenges.cloudflare.com"

    enum NavigationDecision: Equatable {
        case allow
        case openInBrowser
        case cancel
    }

    /// The page, with Turnstile matched to the app's appearance and interface language.
    static func url(colorScheme: ColorScheme, locale: Locale) -> URL {
        var components = URLComponents(url: AppLinks.feedbackVerificationPageURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "theme", value: colorScheme == .dark ? "dark" : "light"),
            URLQueryItem(name: "language", value: locale.language.languageCode == .chinese ? "zh-Hans" : "en"),
        ]
        return components.url!
    }

    static func isPage(_ url: URL) -> Bool {
        let page = AppLinks.feedbackVerificationPageURL
        return url.scheme == page.scheme && url.host == page.host && url.path == page.path
    }

    static func navigationDecision(for url: URL?, inMainFrame: Bool, followsLink: Bool) -> NavigationDecision {
        guard let url else { return .cancel }
        if inMainFrame {
            if isPage(url) { return .allow }
            return followsLink && url.scheme == "https" ? .openInBrowser : .cancel
        }
        // Turnstile builds its frames from about:blank and about:srcdoc, then loads its challenge from Cloudflare.
        if url.scheme == "about" || (url.scheme == "https" && url.host == turnstileHost) { return .allow }
        return .cancel
    }
}
