import SwiftUI
import WebKit

/// Cloudflare Turnstile's 300 × 65 widget, run by the published feedback check page in a web view that keeps no
/// cookies or storage. Each change of `resetCount` asks the page for a new check, after a token is used.
struct TurnstileVerificationView: NSViewRepresentable {
    static let size = CGSize(width: 300, height: 65)

    let pageURL: URL
    let resetCount: Int
    let onEvent: (TurnstileVerificationEvent) -> Void

    func makeCoordinator() -> TurnstileVerificationCoordinator {
        TurnstileVerificationCoordinator(onEvent: onEvent)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: TurnstileVerificationCoordinator.messageHandlerName)
        let webView = WKWebView(frame: CGRect(origin: .zero, size: Self.size), configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // The page is transparent, so the widget sits on the Settings surface in every theme.
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        context.coordinator.resetCount = resetCount
        webView.load(URLRequest(url: pageURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onEvent = onEvent
        guard context.coordinator.resetCount != resetCount else { return }
        context.coordinator.resetCount = resetCount
        webView.evaluateJavaScript("window.resetVerification?.()")
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: TurnstileVerificationCoordinator) {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: TurnstileVerificationCoordinator.messageHandlerName
        )
    }
}
