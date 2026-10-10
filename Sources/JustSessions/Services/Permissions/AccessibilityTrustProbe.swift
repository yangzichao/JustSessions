import ApplicationServices

/// Tells whether macOS trusts the app with Accessibility. CLIs in its terminals get the same answer, since macOS
/// records the permission for the app that started them. Asking without a prompt shows nothing.
struct AccessibilityTrustProbe: Sendable {
    var isProcessTrusted: @Sendable () -> Bool = { AXIsProcessTrusted() }

    func status() -> AppPermissionStatus {
        isProcessTrusted() ? .allowed : .notAllowed
    }
}
