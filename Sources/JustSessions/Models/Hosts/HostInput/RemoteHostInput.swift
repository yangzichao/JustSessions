import Foundation

/// What was typed in the Add SSH host sheet, read as a destination for `ssh`. People paste what they would type in
/// Terminal, such as `ssh devbox`, or add a port. A port can't be kept with the host: `rsync` names its source
/// `host:path`, so the port belongs in `~/.ssh/config`.
enum RemoteHostInput: Equatable {
    case empty
    case destination(String)
    /// A port other than 22.
    case needsPortInConfig(user: String?, hostName: String, port: Int)
    /// `ssh` options, a command, or anything else that isn't one destination.
    case notADestination

    init(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        if words.isEmpty {
            self = .empty
        } else if words.first == "ssh" {
            self = Self.reading(sshArguments: Array(words.dropFirst()))
        } else {
            self = words.count == 1 ? Self.reading(destination: trimmed) : .notADestination
        }
    }

    var validDestination: String? {
        guard case .destination(let destination) = self else { return nil }
        return destination
    }

    /// The `~/.ssh/config` lines that give the host its port, so it can be entered without one.
    static func configLines(user: String?, hostName: String, port: Int) -> String {
        (["Host \(hostName)", "  Port \(port)"] + (user.map { ["  User \($0)"] } ?? [])).joined(separator: "\n")
    }

    /// What follows `ssh`: one destination, with `-p` as the only option it can take.
    private static func reading(sshArguments: [String]) -> RemoteHostInput {
        var port: Int?
        var destinations: [String] = []
        var remaining = sshArguments[...]
        while let argument = remaining.popFirst() {
            if argument == "-p", let value = remaining.popFirst() {
                guard let value = validPort(value) else { return .notADestination }
                port = value
            } else if argument.hasPrefix("-p"), let value = validPort(String(argument.dropFirst(2))) {
                port = value
            } else if argument.hasPrefix("-") {
                return .notADestination
            } else {
                destinations.append(argument)
            }
        }
        guard destinations.count == 1 else { return .notADestination }
        let input = reading(destination: destinations[0])
        guard let port, port != 22, case .destination(let destination) = input else { return input }
        let (user, hostName) = splitUser(destination)
        return .needsPortInConfig(user: user, hostName: hostName, port: port)
    }

    /// `host`, `user@host`, `host:port`, or `ssh://user@host:port`.
    private static func reading(destination: String) -> RemoteHostInput {
        if destination.lowercased().hasPrefix("ssh://") {
            guard let components = URLComponents(string: destination),
                  let hostName = components.host, !hostName.isEmpty,
                  components.path.isEmpty || components.path == "/",
                  components.password == nil, components.query == nil, components.fragment == nil
            else { return .notADestination }
            if let port = components.port, port != 22 {
                return .needsPortInConfig(user: components.user, hostName: hostName, port: port)
            }
            return validated((components.user.map { $0 + "@" } ?? "") + hostName)
        }
        // An IPv6 address has more than one colon, and is no `host:port`.
        let parts = destination.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 2 {
            guard !parts[0].isEmpty, let port = validPort(parts[1]) else { return .notADestination }
            if port == 22 { return validated(parts[0]) }
            let (user, hostName) = splitUser(parts[0])
            return .needsPortInConfig(user: user, hostName: hostName, port: port)
        }
        return validated(destination)
    }

    private static func validated(_ destination: String) -> RemoteHostInput {
        RemoteHostList.normalizedHost(destination).map(RemoteHostInput.destination) ?? .notADestination
    }

    private static func validPort(_ text: String) -> Int? {
        guard let port = Int(text), (1...65535).contains(port) else { return nil }
        return port
    }

    private static func splitUser(_ destination: String) -> (user: String?, hostName: String) {
        guard let at = destination.lastIndex(of: "@") else { return (nil, destination) }
        return (String(destination[..<at]), String(destination[destination.index(after: at)...]))
    }
}
