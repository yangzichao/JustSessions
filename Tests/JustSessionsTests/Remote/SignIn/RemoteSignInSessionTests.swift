import Foundation
import Testing

@testable import JustSessions

/// The session runs a local `sh` script in place of `ssh`: it reads its answers from a pipe, as the command on the
/// host reads them from its terminal, and `echo` stands in for a terminal echoing what's typed.
struct RemoteSignInSessionTests {
    private static let fastTiming = RemoteSignInSession.Timing(
        promptPause: .milliseconds(100),
        linePause: .milliseconds(300),
        pollInterval: .milliseconds(20),
        // Well past the stall at the start of a full run, when the whole test process can wait half a minute.
        timeLimit: .seconds(120)
    )

    private func session(running script: String, timing: RemoteSignInSession.Timing = fastTiming) -> RemoteSignInSession {
        RemoteSignInSession(
            host: "devbox",
            command: "sign-in",
            launcher: RemoteSignInSession.Launcher { _, _ in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", script]
                return process
            },
            timing: timing
        )
    }

    /// Records each question and answers from `answers` by prompt.
    private final class Asker: @unchecked Sendable {
        private let lock = NSLock()
        private let answers: [String: String]
        private let onAsked: @Sendable (SSHAskpassQuestion) -> Void
        private(set) var questions: [SSHAskpassQuestion] = []

        init(_ answers: [String: String], onAsked: @escaping @Sendable (SSHAskpassQuestion) -> Void = { _ in }) {
            self.answers = answers
            self.onAsked = onAsked
        }

        var asked: [SSHAskpassQuestion] { lock.withLock { questions } }

        func ask(_ question: SSHAskpassQuestion) async -> String? {
            lock.withLock { questions.append(question) }
            onAsked(question)
            guard let answer = answers[question.prompt] else {
                // Waits to be taken back, as a question shown in the dialog does.
                while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(10)) }
                return nil
            }
            return answer
        }
    }

    private static let pinThenCode = """
        printf 'Signing in as me\\nPIN: '
        read pin
        echo "$pin"
        printf 'One-time code: '
        read code
        echo "$code"
        [ "$pin" = 1234 ] && [ "$code" = 987654 ]
        """

    @Test func asksEachQuestionInTurnAndSignsIn() async {
        let asker = Asker(["PIN:": "1234", "One-time code:": "987654"])

        let outcome = await session(running: Self.pinThenCode).run(ask: asker.ask)

        #expect(outcome == .signedIn)
        #expect(asker.asked.map(\.prompt) == ["PIN:", "One-time code:"])
        #expect(asker.asked.map(\.context) == ["Signing in as me", nil])
        #expect(asker.asked.allSatisfy { $0.asker == .signInCommand && $0.kind == .secret && $0.host == "devbox" })
    }

    @Test func aQuestionAskedAgainSaysTheAnswerWasntAccepted() async {
        let script = """
            printf 'PIN: '
            read pin
            while [ "$pin" != 1234 ]; do
              printf '\\nWrong PIN.\\nPIN: '
              read pin
            done
            """
        final class Answers: @unchecked Sendable {
            private let lock = NSLock()
            private var remaining = ["0000", "1234"]
            private(set) var asked: [SSHAskpassQuestion] = []
            func ask(_ question: SSHAskpassQuestion) async -> String? {
                lock.withLock {
                    asked.append(question)
                    return remaining.removeFirst()
                }
            }
        }
        let answers = Answers()

        let outcome = await session(running: script).run(ask: answers.ask)

        #expect(outcome == .signedIn)
        #expect(answers.asked.map(\.isAskedAgain) == [false, true])
        #expect(answers.asked.last?.context == "Wrong PIN.")
    }

    @Test func aPromptOnALineOfItsOwnIsAskedOnceTheCommandWaits() async {
        let asker = Asker(["Press your key to type its code": "cccccvbfhrnk"])

        let outcome = await session(running: "echo 'Press your key to type its code'; read code; [ \"$code\" = cccccvbfhrnk ]")
            .run(ask: asker.ask)

        #expect(outcome == .signedIn)
        #expect(asker.asked.map(\.prompt) == ["Press your key to type its code"])
    }

    /// The command goes on printing only once its first line has been asked, as a slow step's would, so the order
    /// never depends on how quickly the session looks.
    @Test func aPauseWhileTheCommandStillWorksTakesItsQuestionBack() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let asked = directory.appendingPathComponent("asked")
        let asker = Asker(
            ["PIN:": "1234"],
            onAsked: { question in
                if question.prompt == "Contacting the server" { FileManager.default.createFile(atPath: asked.path, contents: nil) }
            })

        let outcome = await session(
            running: """
                echo 'Contacting the server'
                while [ ! -f '\(asked.path)' ]; do sleep 0.05; done
                printf 'PIN: '
                read pin
                [ "$pin" = 1234 ]
                """
        ).run(ask: asker.ask)

        #expect(outcome == .signedIn)
        #expect(asker.asked.map(\.prompt) == ["Contacting the server", "PIN:"])
        #expect(asker.asked.last?.context == "Contacting the server")
    }

    @Test func cancellingAQuestionStopsTheCommand() async {
        let started = ContinuousClock.now

        let outcome = await session(running: "printf 'PIN: '; read pin; sleep 600").run { _ in nil }

        // Stopped, not waited for: well short of the command's 10 minutes, even at a full run's slow start.
        #expect(outcome == .cancelled)
        #expect(ContinuousClock.now - started < .seconds(300))
    }

    @Test func aFailureSaysWhatTheCommandPrinted() async {
        let outcome = await session(running: "echo 'Your account is locked'; exit 3").run { _ in nil }

        guard case .failed(let message) = outcome else {
            Issue.record("Expected a failure, got \(outcome)")
            return
        }
        #expect(message.contains("exit status 3"))
        #expect(message.contains("Your account is locked"))
    }

    /// The command outlives any stall of a full run, so only the time limit can end it: in the v1.2.14 release run a
    /// 30-second one ended by itself before the session looked, and signed in.
    @Test func aCommandThatNeverEndsIsStoppedAtTheTimeLimit() async {
        var timing = Self.fastTiming
        timing.timeLimit = .seconds(1)
        let started = ContinuousClock.now

        let outcome = await session(running: "sleep 600", timing: timing).run { _ in nil }

        guard case .failed(let message) = outcome else {
            Issue.record("Expected a failure, got \(outcome)")
            return
        }
        #expect(message.contains("5 minutes") || message.contains("stopped"))
        #expect(ContinuousClock.now - started < .seconds(300))
    }
}
