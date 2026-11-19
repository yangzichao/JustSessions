import Foundation

enum SessionHost: Hashable, Sendable, Identifiable {
    case thisMac
    case ssh(String)

    var id: Self { self }

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
