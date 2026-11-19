import Foundation

enum ConversationAction: Sendable, CaseIterable {
    case new
    case resume
    case branch

    var startsNewSession: Bool { self != .resume }

    var displayName: String {
        switch self {
        case .new: "New"
        case .resume: "Resume"
        case .branch: "Branch"
        }
    }
}
