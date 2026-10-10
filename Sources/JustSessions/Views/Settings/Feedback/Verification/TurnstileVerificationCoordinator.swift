import AppKit
import WebKit

/// Keeps the check's web view on its page and Turnstile's frames, and hands the page's reports to the feedback form.
/// Only the page itself, in the main frame, may report.
@MainActor
final class TurnstileVerificationCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    static let messageHandlerName = "turnstile"

    var onEvent: (TurnstileVerificationEvent) -> Void
    /// The reset count the page last started a check for.
    var resetCount = 0

    init(onEvent: @escaping (TurnstileVerificationEvent) -> Void) {
        self.onEvent = onEvent
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let origin = message.frameInfo.securityOrigin
        let page = AppLinks.feedbackVerificationPageURL
        guard message.frameInfo.isMainFrame, origin.protocol == page.scheme, origin.host == page.host,
              let event = TurnstileVerificationEvent(messageBody: message.body) else { return }
        onEvent(event)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        let decision = FeedbackVerificationPage.navigationDecision(
            for: navigationAction.request.url,
            inMainFrame: navigationAction.targetFrame?.isMainFrame ?? true,
            followsLink: navigationAction.navigationType == .linkActivated
        )
        if decision == .openInBrowser, let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        decisionHandler(decision == .allow ? .allow : .cancel)
    }

    /// Turnstile's links open a new window; they go to the browser instead.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url, url.scheme == "https" { NSWorkspace.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onEvent(.failed)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onEvent(.failed)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        onEvent(.failed)
    }
}
