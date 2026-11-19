import Foundation

enum WaitingForYou {
    static func includes(activity: CLIActivity?, hasUnseenFinishedTurn: Bool) -> Bool {
        reason(activity: activity, hasUnseenFinishedTurn: hasUnseenFinishedTurn) != nil
    }

    static func reason(activity: CLIActivity?, hasUnseenFinishedTurn: Bool) -> SessionAttentionReason? {
        switch activity {
        case .needsInput(let reason): .needsInput(reason: reason)
        case .working: nil
        case .idle, nil: hasUnseenFinishedTurn ? .finishedTurn : nil
        }
    }
}
