/// What the feedback check page reports to the app: `{ event: "verified", token }`, `{ event: "expired" }`, or
/// `{ event: "error" }`, posted by `website/scripts/feedback/app-verification.js`.
enum TurnstileVerificationEvent: Equatable {
    case verified(token: String)
    /// The token went unused for five minutes; Turnstile starts a new check by itself.
    case expired
    /// Turnstile, or the page itself, could not run.
    case failed

    /// The longest token Turnstile issues.
    static let maximumTokenLength = 2048

    init?(messageBody: Any) {
        guard let body = messageBody as? [String: Any], let event = body["event"] as? String else { return nil }
        switch event {
        case "verified":
            guard let token = body["token"] as? String, !token.isEmpty, token.utf16.count <= Self.maximumTokenLength else {
                return nil
            }
            self = .verified(token: token)
        case "expired": self = .expired
        case "error": self = .failed
        default: return nil
        }
    }
}
