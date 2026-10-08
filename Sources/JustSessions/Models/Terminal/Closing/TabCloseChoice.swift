import Foundation

/// What closing a tab does when its CLI can keep running in tmux: ask each time, or do what you chose with Don't ask
/// again in that dialog or in Settings.
enum TabCloseChoice: String, CaseIterable, Identifiable, Sendable {
    case askEachTime
    case keepRunning
    case endSession

    var id: Self { self }

    /// Whether closing the tab without asking ends its tmux session; nil while the app asks each time.
    var endsTmuxSessionWithoutAsking: Bool? {
        switch self {
        case .askEachTime: nil
        case .keepRunning: false
        case .endSession: true
        }
    }
}
