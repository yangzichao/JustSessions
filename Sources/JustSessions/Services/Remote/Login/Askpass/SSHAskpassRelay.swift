import Foundation

/// The askpass program `ssh` runs while the app logs in to a host: the app's own executable, which `ssh` starts with
/// its question as the argument. Started that way, the app shows no window; it hands the question to the running app
/// over the login's socket, prints the answer for `ssh`, and exits. See `SSHAskpassServer`.
enum SSHAskpassRelay {
    /// Set on the login's `ssh`, which passes it on to the helper, so the helper knows where to ask.
    static let socketEnvironmentVariable = "JUSTSESSIONS_ASKPASS_SOCKET"
    /// What kind of question it is; see `SSHAskpassRequest.hint`.
    static let promptHintEnvironmentVariable = "SSH_ASKPASS_PROMPT"
    /// Waiting for someone to type a password or approve a second factor can take a while.
    static let answerTimeout: Duration = .seconds(30 * 60)

    /// The exit status when the app was started as `ssh`'s askpass program, or nil when it was opened as the app.
    /// `ssh` reads a failure as the question being cancelled.
    static func exitStatusIfStartedAsAskpass(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Int32? {
        guard let socketPath = environment[socketEnvironmentVariable] else { return nil }
        let request = SSHAskpassRequest(
            prompt: arguments.dropFirst().first ?? "",
            hint: environment[promptHintEnvironmentVariable]
        )
        guard let answer = answer(to: request, socketPath: socketPath) else { return 1 }
        FileHandle.standardOutput.write(Data((answer + "\n").utf8))
        return 0
    }

    /// The answer typed or chosen in the app, or nil when it was cancelled or the app could not be reached.
    static func answer(to request: SSHAskpassRequest, socketPath: String) -> String? {
        guard let message = SSHAskpassMessageLine.encoded(request),
            let socket = try? UnixStreamSocket(connectingTo: socketPath, timeout: answerTimeout)
        else { return nil }
        defer { socket.close() }
        do {
            try socket.write(message)
            var received = Data()
            while !received.contains(UInt8(ascii: "\n")) {
                guard received.count < SSHAskpassMessageLine.maximumLength else { return nil }
                received.append(try socket.read())
            }
            return SSHAskpassMessageLine.decoded(SSHAskpassReply.self, from: received)?.answer
        } catch {
            return nil
        }
    }
}
