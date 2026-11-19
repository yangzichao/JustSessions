import Foundation

struct SessionNotification: Equatable, Sendable {
    let source: SessionAttentionSource
    let reason: SessionAttentionReason
    let sessionTitle: String
    let provider: ConversationProvider
    let projectName: String

    var title: String { sessionTitle }

    var subtitle: String { "\(provider.rawValue) · \(projectName)" }

    var body: String {
        switch reason {
        case .needsInput(let reason): SessionRunStatus.running(.needsInput(reason: reason)).summary
        case .finishedTurn: "Finished, waiting for your next prompt"
        }
    }
}
