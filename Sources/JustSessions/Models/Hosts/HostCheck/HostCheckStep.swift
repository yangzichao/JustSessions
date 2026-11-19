import Foundation

enum HostCheckStep: Int, CaseIterable, Comparable, Sendable {
    case logIn
    case shellStartup
    case cliLookup
    case hostCommand

    static func < (lhs: HostCheckStep, rhs: HostCheckStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
