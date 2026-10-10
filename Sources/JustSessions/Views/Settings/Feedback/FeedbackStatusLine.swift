import SwiftUI

/// What happened to the last send, or why the spam check is not ready, under the Send button. A check that could not
/// load offers Try again.
struct FeedbackStatusLine: View {
    let phase: FeedbackFormModel.Phase
    let verification: FeedbackFormModel.Verification
    let onRetryVerification: () -> Void

    var body: some View {
        if let status {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(status.text)
                    .foregroundStyle(status.isProblem ? ThemePalette.errorText : ThemePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if verification == .unavailable && phase != .sending {
                    Button("Try again", action: onRetryVerification)
                        .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
                        .accessibilityIdentifier("feedback.retryVerification")
                }
            }
            .font(.callout)
            .accessibilityIdentifier("feedback.status")
        }
    }

    private var status: (text: LocalizedStringKey, isProblem: Bool)? {
        switch phase {
        case .sending: return ("Sending…", false)
        case .sent: return ("Thanks — your feedback was sent.", false)
        case .failed(let failure): return (Self.text(for: failure), true)
        case .writing:
            return verification == .unavailable
                ? ("The spam check couldn't load. Check your connection, or email us.", true)
                : nil
        }
    }

    private static func text(for failure: FeedbackSendFailure) -> LocalizedStringKey {
        switch failure {
        case .invalidFeedback: "The message is empty or too long."
        case .verificationFailed: "The spam check didn't pass. Send again once it finishes."
        case .tooManyRequests: "That's a lot of messages at once. Wait a minute, then send again."
        case .unavailable: "Feedback couldn't be sent right now. Try again later, or email us."
        case .unreachable: "Couldn't reach the feedback server. Check your connection, or email us."
        }
    }
}
