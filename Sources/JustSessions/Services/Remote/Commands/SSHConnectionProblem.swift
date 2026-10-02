import Foundation

/// Why `ssh` could not connect to a host or lost the connection, read from what it printed, so a message can say
/// what happened and what to do about it in plain English.
enum SSHConnectionProblem: Hashable, Sendable {
    /// The host name did not resolve.
    case hostNotFound
    /// Nothing answered: the connection attempt timed out, or there was no route.
    case noAnswer
    /// The host answered but nothing accepts SSH connections on its port.
    case refused
    /// The connection was made and then lost, as when the Mac sleeps or the network changes.
    case connectionLost
    /// The host did not accept a login without a password.
    case loginRefused
    /// The host's key changed, or it is not known and `BatchMode` cannot ask about it.
    case hostKeyNotTrusted
    /// Anything else, with the line `ssh` printed.
    case other(sshMessage: String)

    /// The longest line of `ssh`'s output kept to explain a failure.
    static let maximumMessageLength = 200

    /// Stable parts of OpenSSH's messages, compared without regard to case; the first problem whose text a line
    /// contains wins.
    private static let messageFragments: [(problem: SSHConnectionProblem, fragments: [String])] = [
        (.hostKeyNotTrusted, ["host key verification failed", "remote host identification has changed"]),
        // ssh's own form, "Permission denied (publickey,password).", not a remote command's "…: Permission denied".
        (.loginRefused, ["permission denied (", "too many authentication failures"]),
        (.hostNotFound, ["could not resolve hostname"]),
        (.refused, ["connection refused"]),
        (.connectionLost, ["timeout, server", "broken pipe", "connection reset", "connection closed by", "closed by remote host"]),
        (.noAnswer, ["operation timed out", "connection timed out", "no route to host", "network is unreachable"]),
    ]

    /// Classifies one line `ssh` printed, such as the one `tellingLine(inOutput:)` picks.
    init(sshMessage: String) {
        let lowercasedMessage = sshMessage.lowercased()
        self = Self.messageFragments
            .first { entry in entry.fragments.contains { lowercasedMessage.contains($0) } }?
            .problem ?? .other(sshMessage: sshMessage)
    }

    /// Lines at the end of the output searched for a known problem. `ssh` can print a little after the cause, such
    /// as "Disconnected from …" after "Too many authentication failures"; earlier lines are more likely the remote
    /// command's own output.
    static let linesSearchedForAKnownProblem = 3

    /// The line of `ssh`'s output, its standard error included, that tells what went wrong: the last of the final
    /// few lines naming a known problem, otherwise the last one with any words. Trimmed to one line of at most
    /// `maximumMessageLength` characters; nil when `ssh` printed nothing useful.
    static func tellingLine(inOutput output: String) -> String? {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in line.contains { $0.isLetter } }
        let line = lines.suffix(linesSearchedForAKnownProblem).last { line in
            if case .other = SSHConnectionProblem(sshMessage: line) { return false }
            return true
        } ?? lines.last
        guard let line else { return nil }
        return line.count > maximumMessageLength ? line.prefix(maximumMessageLength - 1) + "…" : line
    }

    /// What happened to `host` and what to do about it, in a sentence or two.
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
            "\(host) didn't accept the SSH login without a password. Check that “ssh \(host)” works in Terminal without asking for a password."
        case .hostKeyNotTrusted:
            "\(host)'s host key has changed or isn't trusted. Connect once with “ssh \(host)” in Terminal to check it."
        case .other(let sshMessage):
            "Couldn't connect to \(host): \(sshMessage)"
        }
    }

    /// Whether trying again later may work without changing anything: the network or the host may be back. A
    /// refused login or an untrusted host key needs a fix first.
    var isLikelyTemporary: Bool {
        switch self {
        case .hostNotFound, .noAnswer, .refused, .connectionLost, .other: true
        case .loginRefused, .hostKeyNotTrusted: false
        }
    }
}
