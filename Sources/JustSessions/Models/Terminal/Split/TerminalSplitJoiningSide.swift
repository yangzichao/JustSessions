import Foundation

extension TerminalSplit {
    enum JoiningSide: Equatable {
        case fixed(Side)
        case sideItCameFrom

        static let left = JoiningSide.fixed(.left)
        static let right = JoiningSide.fixed(.right)
    }
}
