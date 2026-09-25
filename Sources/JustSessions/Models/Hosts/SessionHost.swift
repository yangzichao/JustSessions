import Foundation

/// A machine whose sessions are listed and run: this Mac, or an SSH host from the host list. Every host is listed,
/// refreshed, and started from in the same way; only how its session files are read and its CLI is reached differ.
enum SessionHost: Hashable, Sendable, Identifiable {
    case thisMac
    /// What you would type after `ssh`: a `Host` alias from `~/.ssh/config`, or `user@hostname`.
    case ssh(String)

    var id: Self { self }

    /// The `ssh` destination, or nil for this Mac.
    var sshDestination: String? {
        guard case .ssh(let destination) = self else { return nil }
        return destination
    }

    var displayName: String {
        switch self {
        case .thisMac: "This Mac"
        case .ssh(let destination): destination
        }
    }

    /// The name within a sentence: "on this Mac", "on devbox".
    var nameInSentence: String {
        switch self {
        case .thisMac: "this Mac"
        case .ssh(let destination): destination
        }
    }

    var symbolName: String {
        switch self {
        case .thisMac: "laptopcomputer"
        case .ssh: "server.rack"
        }
    }
}
