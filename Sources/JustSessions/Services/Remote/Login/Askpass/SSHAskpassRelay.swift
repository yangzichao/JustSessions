import Foundation

enum SSHAskpassRelay {
    static let socketEnvironmentVariable = "JUSTSESSIONS_ASKPASS_SOCKET"
    static let promptHintEnvironmentVariable = "SSH_ASKPASS_PROMPT"
    static let answerTimeout: Duration = .seconds(30 * 60)

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
