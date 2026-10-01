import Foundation

/// Why a session's CLI wants you back.
enum SessionAttentionReason: Equatable, Sendable {
    /// Stopped in the middle of a turn until you answer, such as a permission prompt. `reason` is the CLI's own
    /// words for it, such as "input needed".
    case needsInput(reason: String?)
    /// Done with its turn, waiting for your next prompt.
    case finishedTurn

    /// What changed between two activities a CLI told, one sync apart; nil when nothing calls you back. A CLI that
    /// told nothing either time has nothing to compare, so a CLI first seen while it waits, as at launch, stays quiet.
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
