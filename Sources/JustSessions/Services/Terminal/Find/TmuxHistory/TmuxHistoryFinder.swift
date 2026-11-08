import Foundation
import os

/// Finds text in the history of the tmux session a plain terminal's shell runs in, with copy mode's own search
/// (`TmuxHistorySearchCommands`): the tab's terminal shows tmux on its alternate screen, which keeps no scrollback, so
/// the terminal's own find sees only the screen. tmux runs each step off the main actor, on this Mac or over SSH, so
/// what a step found comes later, through `onStepFinished`. A search typed before tmux answered skips the steps queued
/// for the searches it replaced; moves run in order.
@MainActor
final class TmuxHistoryFinder: TerminalTextFinding {
    /// What each step of the current search found, in order.
    var onStepFinished: ((TmuxHistorySearchOutcome) -> Void)?

    private let history: TmuxHistory
    private let commandQueue = DispatchQueue(label: "JustSessions.tmux-history-find", qos: .userInitiated)
    /// Goes up with each new search and each end. A search step queued for an older one is skipped, and what one found
    /// after it is not reported. Ending always runs, so copy mode is left even when another end followed it at once.
    private var generation = 0
    private let latestGeneration = OSAllocatedUnfairLock(initialState: 0)
    /// Copy mode is on for a search, so ending the search leaves it.
    private var hasStartedSearch = false
    /// tmux doesn't say which match it selected, so moves count from the newest, 1; nil once the total changed under
    /// it, as when the shell printed more.
    private var selectedNumber: Int?
    private var lastTotal: Int?

    init(history: TmuxHistory) {
        self.history = history
    }

    func findText(_ query: String) -> TerminalFindMatchCount? {
        guard !query.isEmpty else {
            endTextFind()
            return nil
        }
        startGeneration()
        hasStartedSearch = true
        run(TmuxHistorySearchCommands.startingSearch(for: query, inSession: history.sessionName), step: .start)
        return nil
    }

    func findTextAgain(_ query: String, direction: TerminalFindDirection) -> TerminalFindMatchCount? {
        guard hasStartedSearch else { return findText(query) }
        run(TmuxHistorySearchCommands.movingSearch(direction, for: query, inSession: history.sessionName), step: .move(direction))
        return nil
    }

    func endTextFind() {
        startGeneration()
        guard hasStartedSearch else { return }
        hasStartedSearch = false
        run(TmuxHistorySearchCommands.endingSearch(inSession: history.sessionName), step: .end)
    }

    private enum Step {
        case start
        case move(TerminalFindDirection)
        case end
    }

    private func startGeneration() {
        generation += 1
        selectedNumber = nil
        lastTotal = nil
        let generation = generation
        latestGeneration.withLock { $0 = generation }
    }

    private func run(_ arguments: [String], step: Step) {
        let generation = generation
        let history = history
        let latestGeneration = latestGeneration
        let isEnding = if case .end = step { true } else { false }
        commandQueue.async { [weak self] in
            guard isEnding || latestGeneration.withLock({ $0 }) == generation else { return }
            let output = history.runTmux(arguments)
            guard !isEnding else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation else { return }
                self.onStepFinished?(self.outcome(inOutput: output, after: step))
            }
        }
    }

    private func outcome(inOutput output: String?, after step: Step) -> TmuxHistorySearchOutcome {
        guard let output, let printed = TmuxHistorySearchCommands.printedCount(inOutput: output) else { return .couldNotSearch }
        // Without a count, a search that found none has none, and after a move the count before it stands. One that
        // found some in a tmux that counts nothing shows no count (`TmuxHistorySearchCommands`).
        let total: Int
        if let counted = printed.total {
            total = counted
        } else if printed.foundAny == false {
            total = 0
        } else if !Self.isStart(step), let lastTotal {
            total = lastTotal
        } else {
            selectedNumber = nil
            return .searched(nil)
        }
        if total == 0 || printed.isPartial {
            selectedNumber = nil
        } else if case .move(let direction) = step {
            selectedNumber = selectedNumber.flatMap { total == lastTotal ? Self.number(after: $0, moving: direction, of: total) : nil }
        } else {
            selectedNumber = 1
        }
        lastTotal = total
        return .searched(TerminalFindMatchCount(total: total, selectedNumber: selectedNumber, exceedsCountLimit: printed.isPartial))
    }

    private static func isStart(_ step: Step) -> Bool {
        if case .start = step { return true }
        return false
    }

    /// Matches are numbered from the newest, and both directions wrap around.
    static func number(after number: Int, moving direction: TerminalFindDirection, of total: Int) -> Int {
        switch direction {
        case .towardOlder: number % total + 1
        case .towardNewer: number == 1 ? total : number - 1
        }
    }
}
