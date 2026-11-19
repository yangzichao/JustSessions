import Foundation

enum SSHConnectionProblem: Hashable, Sendable {
    case hostNotFound
    case noAnswer
    case refused
    case connectionLost
    case loginRefused
    case hostKeyNotTrusted
    case windowsHost
    case other(sshMessage: String)

    static let maximumMessageLength = 200

    private static let messageFragments: [(problem: SSHConnectionProblem, fragments: [String])] = [
        (.hostKeyNotTrusted, ["host key verification failed", "remote host identification has changed"]),
        // ssh's own form, "Permission denied (publickey,password).", not a remote command's "…: Permission denied".
        (.loginRefused, ["permission denied (", "too many authentication failures"]),
        (.hostNotFound, ["could not resolve hostname"]),
        (.refused, ["connection refused"]),
        (.connectionLost, ["timeout, server", "broken pipe", "connection reset", "connection closed by", "closed by remote host"]),
        (.noAnswer, ["operation timed out", "connection timed out", "no route to host", "network is unreachable", "host is down"]),
    ]

    init(sshMessage: String) {
        let lowercasedMessage = sshMessage.lowercased()
        self =
            Self.messageFragments
            .first { entry in entry.fragments.contains { lowercasedMessage.contains($0) } }?
            .problem ?? .other(sshMessage: sshMessage)
    }

    init(sshOutput output: String) {
        self.init(sshMessage: Self.tellingLine(inOutput: output) ?? "ssh exited without saying why.")
    }

    /// Lines at the end of the output searched for a known problem. `ssh` can print a little after the cause, such
    /// as "Disconnected from …" after "Too many authentication failures"; earlier lines are more likely the remote
    /// command's own output.
    static let linesSearchedForAKnownProblem = 3

    static func tellingLine(inOutput output: String) -> String? {
        let lines =
            output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in line.contains { $0.isLetter } }
        let line =
            lines.suffix(linesSearchedForAKnownProblem).last { line in
                if case .other = SSHConnectionProblem(sshMessage: line) { return false }
                return true
            } ?? lines.last
        guard let line else { return nil }
        return line.count > maximumMessageLength ? line.prefix(maximumMessageLength - 1) + "…" : line
    }

    func explanation(host: String) -> String {
        switch self {
        case .hostNotFound:
            "\(host) couldn't be found. Check the host name and your network or VPN."
        case .noAnswer:
            "\(host) didn't answer. Check your network or VPN."
        case .refused:
            "\(host) refused the SSH connection. Check that SSH is running on it."
        case .connectionLost:
            "The connection to \(host) was lost, for example because the Mac slept or the network changed."
        case .loginRefused:
            "\(host) asks for a password, a passphrase, or a code. Click Connect… on its heading to log in."
        case .hostKeyNotTrusted:
            "\(host)'s host key isn't trusted yet, or has changed. Click Connect… on its heading to check it."
        case .windowsHost:
            "\(host) runs Windows, which JustSessions doesn't support. Run your CLIs in WSL on it, and connect to WSL over SSH instead."
        case .other(let sshMessage):
            "Couldn't connect to \(host): \(sshMessage)"
        }
    }

    func explanationBesideConnect(host: String) -> String {
        switch self {
        case .loginRefused:
            "\(host) asks for a password, a passphrase, or a code. Click Connect… to log in."
        case .hostKeyNotTrusted:
            "\(host)'s host key isn't trusted yet, or has changed. Click Connect… to check it."
        case .hostNotFound, .noAnswer, .refused, .connectionLost, .windowsHost, .other:
            explanation(host: host)
        }
    }

    /// Why logging in with Connect… failed, in a sentence or two. Its questions were asked, so a refused login means
    /// what was typed was wrong, a host key still not trusted has changed, and a connection that closed most likely
    /// waited too long for an answer: OpenSSH's server gives up after two minutes.
    func loginFailureExplanation(host: String) -> String {
        switch self {
        case .loginRefused:
            "\(host) refused the login. Check the password, passphrase, or code, then try again."
        case .hostKeyNotTrusted:
            "\(host)'s host key has changed. Check it with “ssh \(host)” in Terminal."
        case .connectionLost:
            "The connection to \(host) closed during the login, for example because the host stopped waiting for an answer. Try again."
        case .hostNotFound, .noAnswer, .refused, .windowsHost, .other:
            explanation(host: host)
        }
    }

    var isFixedByLoggingIn: Bool {
        switch self {
        case .loginRefused, .hostKeyNotTrusted: true
        case .hostNotFound, .noAnswer, .refused, .connectionLost, .windowsHost, .other: false
        }
    }

    var meansHostIsOutOfReach: Bool {
        switch self {
        case .hostNotFound, .noAnswer, .refused: true
        case .connectionLost, .loginRefused, .hostKeyNotTrusted, .windowsHost, .other: false
        }
    }

    var isLikelyTemporary: Bool {
        switch self {
        case .hostNotFound, .noAnswer, .refused, .connectionLost, .other: true
        case .loginRefused, .hostKeyNotTrusted, .windowsHost: false
        }
    }
}
