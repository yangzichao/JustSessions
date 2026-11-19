import ApplicationServices

struct AccessibilityTrustProbe: Sendable {
    var isProcessTrusted: @Sendable () -> Bool = { AXIsProcessTrusted() }

    func status() -> AppPermissionStatus {
        isProcessTrusted() ? .allowed : .notAllowed
    }
}
