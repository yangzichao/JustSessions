import Foundation

enum SessionAttentionReason: Equatable, Sendable {
    case needsInput(reason: String?)
    case finishedTurn

    static func reason(changingFrom previous: CLIActivity?, to current: CLIActivity?) -> Self? {
        switch (previous, current) {
        case (.working, .idle):
            return .finishedTurn
        case (.working, .needsInput(let reason)), (.idle, .needsInput(let reason)):
            return .needsInput(reason: reason)
        default:
            return nil
        }
    }
}
