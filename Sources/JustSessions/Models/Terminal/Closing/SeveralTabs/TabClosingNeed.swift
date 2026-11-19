import Foundation

enum TabClosingNeed: Equatable, Sendable {
    case nothingStarted
    case alreadyEnded
    case canKeepCLIRunning
    case plainTerminal
    case cliStopsWithTab

    var hasRunningCLI: Bool {
        switch self {
        case .canKeepCLIRunning, .cliStopsWithTab: true
        case .nothingStarted, .alreadyEnded, .plainTerminal: false
        }
    }

    init(isWaitingToBeShown: Bool, closingStopsNothing: Bool, canKeepCLIRunningAfterClose: Bool, isPlainTerminal: Bool) {
        if isWaitingToBeShown {
            self = .nothingStarted
        } else if closingStopsNothing {
            self = .alreadyEnded
        } else if canKeepCLIRunningAfterClose {
            self = .canKeepCLIRunning
        } else if isPlainTerminal {
            self = .plainTerminal
        } else {
            self = .cliStopsWithTab
        }
    }
}
