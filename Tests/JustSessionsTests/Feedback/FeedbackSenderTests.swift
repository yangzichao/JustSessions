import Foundation
import Testing
@testable import JustSessions

struct FeedbackSenderTests {
    private let submission = FeedbackSubmission(
        message: "  Search is slow  \n",
        contact: " me@example.com ",
        environment: FeedbackEnvironment(appVersion: "1.0.13 (32)", macOSVersion: "26.0.1"),
        turnstileToken: "token-1"
    )

    private actor RequestRecorder {
        private(set) var requests: [URLRequest] = []
        func record(_ request: URLRequest) { requests.append(request) }
    }

    private func sender(answering body: String, recorder: RequestRecorder = RequestRecorder()) -> FeedbackSender {
        FeedbackSender { request in
            await recorder.record(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
    }

    @Test func postsTrimmedJSONFromTheAppToTheWorker() async throws {
        let recorder = RequestRecorder()
        let result = await sender(answering: #"{"result":"sent"}"#, recorder: recorder).send(submission)

        #expect((try? result.get()) != nil)
        let request = try #require(await recorder.requests.first)
        #expect(request.url == AppLinks.feedbackEndpointURL)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let bodyData = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: String])
        #expect(body == [
            "message": "Search is slow",
            "contact": "me@example.com",
            "source": "app",
            "appVersion": "1.0.13 (32)",
            "macOSVersion": "26.0.1",
            "turnstileToken": "token-1",
        ])
    }

    /// The Worker refuses `"contact": null`.
    @Test func aBlankContactIsLeftOut() throws {
        let withoutContact = FeedbackSubmission(
            message: "Hi", contact: "   ", environment: FeedbackEnvironment(appVersion: "1.0", macOSVersion: "26.0"),
            turnstileToken: "token"
        )
        let body = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(withoutContact)) as? [String: String])
        #expect(body["contact"] == nil)
        #expect(Set(body.keys) == ["message", "source", "appVersion", "macOSVersion", "turnstileToken"])
    }

    @Test(arguments: [
        (#"{"result":"invalid-feedback"}"#, FeedbackSendFailure.invalidFeedback),
        (#"{"result":"verification-failed"}"#, .verificationFailed),
        (#"{"result":"too-many-requests"}"#, .tooManyRequests),
        (#"{"result":"unavailable"}"#, .unavailable),
        (#"{"result":"something new"}"#, .unavailable),
        ("<html>Bad gateway</html>", .unavailable),
        ("", .unavailable),
    ])
    func eachRefusalKeepsItsReason(body: String, failure: FeedbackSendFailure) async {
        let result = await sender(answering: body).send(submission)
        #expect(result == .failure(failure))
    }

    @Test func aConnectionFailureMeansTheWorkerWasUnreachable() async {
        let offline = FeedbackSender { _ in throw URLError(.notConnectedToInternet) }
        #expect(await offline.send(submission) == .failure(.unreachable))
    }
}

extension Result: @retroactive Equatable where Success == Void, Failure == FeedbackSendFailure {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success): true
        case let (.failure(left), .failure(right)): left == right
        default: false
        }
    }
}
