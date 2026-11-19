import Foundation

/// How a sign-in ended.
enum RemoteSignInOutcome: Equatable, Sendable {
    case signedIn
    case cancelled
    /// Why, in the command's or `ssh`'s own words where it said any.
    case failed(String)
}

/// Runs a host's sign-in command once, with a terminal on the host, so it asks as it would if you typed it there.
/// Whenever the command stops printing, its last line is taken as a question and asked in a dialog; the answer goes to
/// the command, and nothing typed is kept. Output that comes while a question shows takes it back, so a command that
/// pauses mid-way doesn't leave a question that was never asked.
struct RemoteSignInSession: Sendable {
    /// Starts the command; tests start a local script instead of `ssh`.
    struct Launcher: Sendable {
        let makeProcess: @Sendable (_ host: String, _ command: String) -> Process

        /// `ssh -tt` gives the command a terminal on the host while this end reads and writes plain pipes. It goes
        /// through the host's Connect… login when there is one, and runs in the login shell tabs use.
        static let ssh = Launcher { host, command in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            let startup = RemoteHostShellStartups.shared.startup(on: host)
            process.arguments =
                ["-tt", "-o", "BatchMode=yes", "-o", "LogLevel=ERROR"]
                + RemoteHostCommandRunner.connectionSettingOptions
                + SSHLoginConnections.shared.connectionOptions(for: host)
                + [host, startup.command(running: command)]
            process.environment = SSHProcessEnvironment.standard
            return process
        }
    }

    struct Timing: Sendable {
        /// How long a line left without its newline must stand before it's asked, as `PIN: ` is.
        var promptPause: Duration = .milliseconds(400)
        /// How long the command must be quiet after a whole line before that line is asked.
        var linePause: Duration = .milliseconds(1500)
        /// How often the output and the command are looked at.
        var pollInterval: Duration = .milliseconds(100)
        /// A sign-in that takes longer is stopped.
        var timeLimit: Duration = .seconds(300)
    }

    let host: String
    let command: String
    var launcher = Launcher.ssh
    var timing = Timing()

    func run(ask: @escaping @Sendable (SSHAskpassQuestion) async -> String?) async -> RemoteSignInOutcome {
        let process = launcher.makeProcess(host, command)
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        let state = RunState()
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            // At the end of the output the handler would go on being called with nothing.
            if data.isEmpty { handle.readabilityHandler = nil }
            state.receiveOutput(data)
        }
        errors.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            state.receiveErrors(data)
        }
        process.terminationHandler = { state.noteExit($0.terminationStatus) }
        do {
            try process.run()
        } catch {
            return .failed(error.localizedDescription)
        }
        defer {
            output.fileHandleForReading.readabilityHandler = nil
            errors.fileHandleForReading.readabilityHandler = nil
            try? input.fileHandleForWriting.close()
        }

        let clock = ContinuousClock()
        let deadline = clock.now + timing.timeLimit
        var shownQuestion: (task: Task<Void, Never>, answer: AnswerBox, outputVersion: Int, prompt: String)?
        var lastAskedPrompt: String?

        func stop() {
            shownQuestion?.task.cancel()
            if process.isRunning { process.terminate() }
        }

        while true {
            if Task.isCancelled {
                stop()
                return .cancelled
            }
            if state.exitStatus != nil {
                shownQuestion?.task.cancel()
                return await finish(state: state, process: process, clock: clock)
            }
            if clock.now >= deadline {
                stop()
                return .failed(AppLocalization.string("The sign-in command took longer than 5 minutes, so it was stopped."))
            }
            let snapshot = state.snapshot()
            if let question = shownQuestion {
                if snapshot.outputVersion != question.outputVersion {
                    // The command went on printing, so it wasn't waiting for this.
                    question.task.cancel()
                    shownQuestion = nil
                } else if let answer = question.answer.value {
                    shownQuestion = nil
                    guard let answer else {
                        stop()
                        return .cancelled
                    }
                    state.noteAnswered(answer)
                    lastAskedPrompt = question.prompt
                    try? input.fileHandleForWriting.write(contentsOf: Data((answer + "\n").utf8))
                }
            } else if let prompt = snapshot.output.question,
                clock.now - snapshot.lastOutputAt >= (snapshot.output.endsMidLine ? timing.promptPause : timing.linePause)
            {
                let signInQuestion = SSHAskpassQuestion(
                    signInOn: host,
                    prompt: prompt,
                    context: snapshot.output.context,
                    previousPrompt: lastAskedPrompt
                )
                let answer = AnswerBox()
                let task = Task { answer.set(await ask(signInQuestion)) }
                shownQuestion = (task, answer, snapshot.outputVersion, prompt)
            }
            try? await Task.sleep(for: timing.pollInterval)
        }
    }

    private func finish(state: RunState, process: Process, clock: ContinuousClock) async -> RemoteSignInOutcome {
        // The last of the output can arrive just after the command ends.
        let drainDeadline = clock.now + .milliseconds(500)
        while clock.now < drainDeadline, !state.hasReachedEndOfOutput { try? await Task.sleep(for: .milliseconds(20)) }
        let snapshot = state.snapshot()
        switch snapshot.exitStatus {
        case 0?:
            return .signedIn
        case RemoteHostCommandRunner.connectionFailureExitStatus?:
            let reason = snapshot.errors.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failed(reason.isEmpty ? AppLocalization.string("Couldn't connect to \(host).") : reason)
        default:
            let status = snapshot.exitStatus ?? -1
            let printed = snapshot.output.failureText
            let summary = AppLocalization.string("The sign-in command ended with exit status \(Int(status)).")
            return .failed(printed.map { "\(summary)\n\n\($0)" } ?? summary)
        }
    }
}

/// What the running command printed and whether it ended, shared between the pipes' handlers and the session.
private final class RunState: @unchecked Sendable {
    struct Snapshot {
        let output: RemoteSignInOutput
        let outputVersion: Int
        let lastOutputAt: ContinuousClock.Instant
        let exitStatus: Int32?
        let errors: String
    }

    private let lock = NSLock()
    private var output = RemoteSignInOutput()
    private var outputVersion = 0
    private var lastOutputAt = ContinuousClock.now
    private var errors = ""
    private var endOfOutput = false
    private var status: Int32?

    var exitStatus: Int32? { lock.withLock { status } }
    var hasReachedEndOfOutput: Bool { lock.withLock { endOfOutput } }

    func receiveOutput(_ data: Data) {
        lock.withLock {
            guard !data.isEmpty else {
                endOfOutput = true
                return
            }
            let hadText = output.text
            output.append(data)
            // Swallowed echo or escape sequences alone aren't new output.
            if output.text != hadText { outputVersion += 1 }
            lastOutputAt = .now
        }
    }

    func receiveErrors(_ data: Data) {
        lock.withLock { errors += String(decoding: data, as: UTF8.self) }
    }

    func noteExit(_ exitStatus: Int32) {
        lock.withLock { status = exitStatus }
    }

    func noteAnswered(_ answer: String) {
        lock.withLock {
            output.noteAnswered(answer)
            outputVersion += 1
            lastOutputAt = .now
        }
    }

    func snapshot() -> Snapshot {
        lock.withLock {
            Snapshot(output: output, outputVersion: outputVersion, lastOutputAt: lastOutputAt, exitStatus: status, errors: errors)
        }
    }
}

/// A question's answer once it has one; `.some(nil)` is Cancel.
private final class AnswerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var answer: String??

    var value: String?? { lock.withLock { answer } }

    func set(_ answer: String?) {
        lock.withLock { self.answer = .some(answer) }
    }
}
