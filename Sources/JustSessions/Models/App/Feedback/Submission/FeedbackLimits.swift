/// The longest feedback the Worker in `Cloudflare/Feedback` stores, in UTF-16 code units as it counts them. Its tests
/// check these against `website/scripts/feedback/feedback-contract.js`.
enum FeedbackLimits {
    static let maximumMessageLength = 5000
    static let maximumContactLength = 200
}
