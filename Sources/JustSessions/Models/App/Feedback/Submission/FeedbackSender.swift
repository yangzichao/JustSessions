import Foundation

/// Posts feedback to the Worker in `Cloudflare/Feedback`. The live sender uses an ephemeral session, so no cookie or
/// cached response outlives the request.
struct FeedbackSender: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    let transport: Transport

    static let live: FeedbackSender = {
        let session = URLSession(configuration: .ephemeral)
        return FeedbackSender { request in try await session.data(for: request) }
    }()

    func send(_ submission: FeedbackSubmission) async -> Result<Void, FeedbackSendFailure> {
        var request = URLRequest(url: AppLinks.feedbackEndpointURL, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(submission)
        } catch {
            return .failure(.invalidFeedback)
        }

        let data: Data
        do {
            (data, _) = try await transport(request)
        } catch {
            return .failure(.unreachable)
        }
        let workerResult = (try? JSONDecoder().decode(WorkerAnswer.self, from: data))?.result
        if let failure = FeedbackSendFailure(workerResult: workerResult) { return .failure(failure) }
        return .success(())
    }

    /// Every answer the Worker gives the app is `{ "result": … }`.
    private struct WorkerAnswer: Decodable {
        let result: String
    }
}
