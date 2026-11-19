import Foundation

@testable import JustSessions

/// Stands in for `ssh`: records each command and answers with a fixed result, or one for each command.
final class RemoteCommandRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedCommands: [(host: String, command: String)] = []

    var commands: [(host: String, command: String)] {
        lock.withLock { recordedCommands }
    }

    func runner(answering result: (exitStatus: Int32, output: String)?) -> RemoteHostCommandRunner {
        runner(answeringEach: { _ in result })
    }

    func runner(
        answeringEach answer: @escaping @Sendable (_ command: String) -> (exitStatus: Int32, output: String)?
    ) -> RemoteHostCommandRunner {
        RemoteHostCommandRunner { host, command, _ in
            self.lock.withLock { self.recordedCommands.append((host, command)) }
            return answer(command)
        }
    }
}
