import Foundation
import Testing
@testable import JustSessions

@MainActor
struct FeedbackFormModelTests {
    private let environment = FeedbackEnvironment(appVersion: "1.0.13 (32)", macOSVersion: "26.0.1")

    private final class SentSubmissions: @unchecked Sendable {
        var submissions: [FeedbackSubmission] = []
    }

    private func model(answering workerResult: String = "sent", sent: SentSubmissions = SentSubmissions()) -> FeedbackFormModel {
        FeedbackFormModel(environment: environment, sender: FeedbackSender { request in
            sent.submissions.append(try JSONDecoder().decode(SentBody.self, from: request.httpBody!).submission)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(#"{"result":"\#(workerResult)"}"#.utf8), response)
        })
    }

    /// The fields the model sends, read back from the request body.
    private struct SentBody: Decodable {
        let message: String
        let contact: String?
        let turnstileToken: String

        var submission: FeedbackSubmission {
            FeedbackSubmission(
                message: message, contact: contact ?? "",
                environment: FeedbackEnvironment(appVersion: "1.0.13 (32)", macOSVersion: "26.0.1"),
                turnstileToken: turnstileToken
            )
        }
    }

    @Test func sendWaitsForAMessageAndASolvedCheck() {
        let form = model()
        #expect(!form.canSend)
        form.message = "   \n"
        form.verificationChanged(.verified(token: "token-1"))
        #expect(!form.canSend)
        form.message = "Love the tabs"
        #expect(form.canSend)
        form.verificationChanged(.expired)
        #expect(!form.canSend)
        form.verificationChanged(.verified(token: "token-2"))
        form.verificationChanged(.failed)
        #expect(form.verification == .unavailable)
        #expect(!form.canSend)
    }

    @Test func textOverTheWorkersLimitsKeepsSendDisabled() {
        let form = model()
        form.verificationChanged(.verified(token: "token-1"))
        form.message = String(repeating: "a", count: FeedbackLimits.maximumMessageLength)
        #expect(form.canSend)
        // An emoji is two UTF-16 code units, as JavaScript counts it.
        form.message = String(repeating: "a", count: FeedbackLimits.maximumMessageLength - 1) + "🙂"
        #expect(form.isMessageTooLong)
        #expect(!form.canSend)
        form.message = "Fine"
        form.contact = String(repeating: "a", count: FeedbackLimits.maximumContactLength + 1)
        #expect(form.isContactTooLong)
        #expect(!form.canSend)
    }

    @Test func aSentMessageClearsTheFormAndItsTokenIsNotUsedAgain() async {
        let sent = SentSubmissions()
        let form = model(sent: sent)
        form.message = "Love the tabs"
        form.contact = "me@example.com"
        form.verificationChanged(.verified(token: "token-1"))

        await form.send()

        #expect(sent.submissions.map(\.turnstileToken) == ["token-1"])
        #expect(sent.submissions.first?.contact == "me@example.com")
        #expect(form.phase == .sent)
        #expect(form.message.isEmpty)
        #expect(form.contact.isEmpty)
        #expect(form.verification == .checking)
        #expect(form.verificationResetCount == 1)
        await form.send()
        #expect(sent.submissions.count == 1)
    }

    @Test func aRefusedMessageStaysToSendAgainWithANewCheck() async {
        let form = model(answering: "verification-failed")
        form.message = "Love the tabs"
        form.verificationChanged(.verified(token: "token-1"))

        await form.send()

        #expect(form.phase == .failed(.verificationFailed))
        #expect(form.message == "Love the tabs")
        #expect(!form.canSend)
        form.verificationChanged(.verified(token: "token-2"))
        #expect(form.canSend)
    }

    @Test func editingAfterASendClearsWhatItReported() async {
        let form = model()
        form.message = "Love the tabs"
        form.verificationChanged(.verified(token: "token-1"))
        await form.send()
        #expect(form.phase == .sent)
        form.message = "One more thing"
        #expect(form.phase == .writing)
    }

    @Test func aNewCheckPageForgetsTheOldToken() {
        let form = model()
        form.verificationChanged(.verified(token: "token-1"))
        form.verificationRestarted()
        #expect(form.verification == .checking)
    }
}
