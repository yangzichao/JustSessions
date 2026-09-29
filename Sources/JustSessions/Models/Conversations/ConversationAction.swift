import Foundation

enum ConversationAction: Sendable, CaseIterable {
    case new
    case resume
    case branch

    /// New and Branch run a session of their own, whose id the app learns once the CLI writes it.
    var startsNewSession: Bool { self != .resume }

    var displayName: String {
        switch self {
        case .new: "New"
        case .resume: "Resume"
        case .branch: "Branch"
        }
    }
}
