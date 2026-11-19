import Foundation

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

    var nonStandardPort: String? { port == "22" ? nil : port }
}

struct SSHHostSameMachineCheck: Equatable, Sendable {
    let identity: SSHHostIdentity?
    let listedHostWithSameIdentity: String?

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
