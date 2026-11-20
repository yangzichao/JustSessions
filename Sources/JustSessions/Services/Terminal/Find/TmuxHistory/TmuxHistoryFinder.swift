import Foundation
import os

@MainActor
final class TmuxHistoryFinder {
    var onStepFinished: ((TmuxHistorySearchOutcome) -> Void)?

    private let history: TmuxHistory
    private let commandQueue = DispatchQueue(label: "JustSessions.tmux-history-find", qos: .userInitiated)
    private var generation = 0
    private let latestGeneration = OSAllocatedUnfairLock(initialState: 0)
    private var hasStartedSearch = false
    /// tmux doesn't say which match it selected, so moves count from the newest, 1; nil once the total changed under
    /// it, as when the shell printed more.
    private var selectedNumber: Int?
    private var lastTotal: Int?

    init(history: TmuxHistory) {
        self.history = history
    }

    func findText(_ query: String) {
        guard !query.isEmpty else {
            endTextFind()
            return
        }
        startGeneration()
        hasStartedSearch = true
        run(TmuxHistorySearchCommands.startingSearch(for: query, inSession: history.sessionName), step: .start)
    }

    func findTextAgain(_ query: String, direction: TerminalFindDirection) {
        guard hasStartedSearch else {
            findText(query)
            return
        }
        run(TmuxHistorySearchCommands.movingSearch(direction, for: query, inSession: history.sessionName), step: .move(direction))
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

    static func number(after number: Int, moving direction: TerminalFindDirection, of total: Int) -> Int {
        switch direction {
        case .towardOlder: number % total + 1
        case .towardNewer: number == 1 ? total : number - 1
        }
    }
}
