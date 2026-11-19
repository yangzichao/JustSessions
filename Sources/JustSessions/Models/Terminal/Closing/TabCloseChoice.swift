import Foundation

enum TabCloseChoice: String, CaseIterable, Identifiable, Sendable {
    case askEachTime
    case keepRunning
    case endSession

    var id: Self { self }

    var endsTmuxSessionWithoutAsking: Bool? {
        switch self {
        case .askEachTime: nil
        case .keepRunning: false
        case .endSession: true
        }
    }
}
