import Foundation

/// What Codex's shared background server says one of its threads is doing, as `thread/read` gives it:
/// `{"type":"active","activeFlags":["waitingOnApproval"]}`, `{"type":"active","activeFlags":[]}`, `{"type":"idle"}`,
/// `{"type":"notLoaded"}`, or `{"type":"systemError"}`.
enum CodexThreadStatus {
    private static let waitingOnYouFlags: Set<String> = ["waitingOnApproval", "waitingOnUserInput"]

    /// In a turn that waits for your approval of a command or edit, or for your answer to a question.
    static func isWaitingOnYou(_ status: Any?) -> Bool {
        guard let status = status as? [String: Any], status["type"] as? String == "active",
            let flags = status["activeFlags"] as? [String]
        else { return false }
        return flags.contains(where: waitingOnYouFlags.contains)
    }
}
