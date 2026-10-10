import Foundation

/// The account and machine `ssh` reaches for a host, after `~/.ssh/config`. Two hosts with the same identity list the
/// same sessions, such as an alias `devbox` and the `me@192.0.2.10` it stands for. The jump host and proxy are part of
/// it, since one address behind two jump hosts can be two machines.
struct SSHHostIdentity: Hashable, Sendable {
    let user: String
    let hostName: String
    let port: String
    let proxyJump: String?
    let proxyCommand: String?

    init?(configuration: SSHHostConfiguration) {
        guard let user = configuration.user, let hostName = configuration.hostName, let port = configuration.port
        else { return nil }
        self.user = user
        self.hostName = hostName
        self.port = port
        proxyJump = configuration.value(of: "proxyjump")
        proxyCommand = configuration.value(of: "proxycommand")
    }

    var userAtHostName: String { "\(user)@\(hostName)" }

    /// Nil for the standard port.
    var nonStandardPort: String? { port == "22" ? nil : port }
}

/// Where a host being added connects, and which listed host connects to the same place.
struct SSHHostSameMachineCheck: Equatable, Sendable {
    let identity: SSHHostIdentity?
    let listedHostWithSameIdentity: String?

    /// `resolve` stands in for `ssh -G`.
    static func check(
        host: String,
        listedHosts: [String],
        resolve: (String) -> SSHHostIdentity? = { SSHHostConfiguration.resolve(host: $0).flatMap(SSHHostIdentity.init) }
    ) -> SSHHostSameMachineCheck {
        guard let identity = resolve(host) else { return SSHHostSameMachineCheck(identity: nil, listedHostWithSameIdentity: nil) }
        let sameHost = listedHosts.first { $0 != host && resolve($0) == identity }
        return SSHHostSameMachineCheck(identity: identity, listedHostWithSameIdentity: sameHost)
    }
}
