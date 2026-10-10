import Foundation
import Observation

/// The feedback being written in Settings. One draft lasts while the app runs, so closing Settings or switching pages
/// keeps it. Send waits for a message within the Worker's limits and a Turnstile token, and uses each token once.
@MainActor
@Observable
final class FeedbackFormModel {
    static let shared = FeedbackFormModel(environment: .current, sender: .live)

    enum Phase: Equatable {
        case writing
        case sending
        case sent
        case failed(FeedbackSendFailure)
    }

    enum Verification: Equatable {
        case checking
        case verified(token: String)
        /// Turnstile could not run, such as while offline or when it is blocked.
        case unavailable
    }

    /// Editing after a send clears what that send reported.
    var message = "" {
        didSet { if phase != .sending { phase = .writing } }
    }
    var contact = "" {
        didSet { if phase != .sending { phase = .writing } }
    }
    private(set) var phase: Phase = .writing
    private(set) var verification: Verification = .checking
    /// Grows each time a token is used, so the check page starts a new check.
    private(set) var verificationResetCount = 0
    let environment: FeedbackEnvironment
    private let sender: FeedbackSender

    init(environment: FeedbackEnvironment, sender: FeedbackSender) {
        self.environment = environment
        self.sender = sender
    }

    var isMessageTooLong: Bool {
        trimmed(message).utf16.count > FeedbackLimits.maximumMessageLength
    }

    var isContactTooLong: Bool {
        trimmed(contact).utf16.count > FeedbackLimits.maximumContactLength
    }

    var canSend: Bool {
        guard phase != .sending, case .verified = verification else { return false }
        return !trimmed(message).isEmpty && !isMessageTooLong && !isContactTooLong
    }

    func verificationChanged(_ event: TurnstileVerificationEvent) {
        switch event {
        case .verified(let token): verification = .verified(token: token)
        case .expired: verification = .checking
        case .failed: verification = .unavailable
        }
    }

    /// A new check page is loading, such as when the page opens again; any earlier token belonged to the old one.
    func verificationRestarted() {
        verification = .checking
    }

    func send() async {
        guard canSend, case .verified(let token) = verification else { return }
        let submission = FeedbackSubmission(message: message, contact: contact, environment: environment, turnstileToken: token)
        verification = .checking
        verificationResetCount += 1
        phase = .sending
        switch await sender.send(submission) {
        case .success:
            message = ""
            contact = ""
            phase = .sent
        case .failure(let failure):
            phase = .failed(failure)
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
