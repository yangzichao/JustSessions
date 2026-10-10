import Testing
@testable import JustSessions

struct AccessibilityTrustProbeTests {
    @Test func aTrustedAppIsAllowed() {
        #expect(AccessibilityTrustProbe(isProcessTrusted: { true }).status() == .allowed)
    }

    @Test func anUntrustedAppIsNotAllowed() {
        #expect(AccessibilityTrustProbe(isProcessTrusted: { false }).status() == .notAllowed)
    }

    @Test func checkingAsksTheProbe() async {
        let checker = SystemPermissionChecker(accessibilityTrustProbe: AccessibilityTrustProbe(isProcessTrusted: { true }))
        #expect(await checker.status(of: .accessibility) == .allowed)
    }
}
