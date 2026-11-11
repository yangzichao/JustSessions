import Darwin
import Foundation

/// Why a port couldn't be forwarded, as the Forward a port sheet says it; see `SSHPortForwards`. Ports go into the
/// messages as text, since a localized number would be grouped, as in "3,000".
enum SSHPortForwardFailure: Hashable, Sendable {
    case invalidPort
    case localPortForwardedAlready(SSHPortForward)
    case couldNotConnect(host: String, SSHConnectionProblem)
    /// Another program on this Mac listens on the port; `sshMessage` is what `ssh` printed, when it could be read.
    case localPortInUse(port: Int, sshMessage: String)
    case refused(sshMessage: String)
    /// The host doesn't let the connection reach the port, as when its `sshd` turns off forwarding.
    case refusedByHost(host: String, sshMessage: String)

    var message: String {
        switch self {
        case .invalidPort:
            AppLocalization.string("Enter a port from 1 to 65535.")
        case .localPortForwardedAlready(let forward):
            AppLocalization.string(
                "Port \(String(forward.localPort)) on this Mac already forwards to port \(String(forward.remotePort)) on \(forward.host)."
            )
        case .couldNotConnect(let host, let problem):
            problem.explanation(host: host)
        case .localPortInUse(let port, let sshMessage):
            AppLocalization.string("Another program on this Mac uses port \(String(port)). Choose another port on this Mac.")
                + "\n" + sshMessage
        case .refused(let sshMessage):
            AppLocalization.string("ssh couldn't forward the port: \(sshMessage)")
        case .refusedByHost(let host, let sshMessage):
            AppLocalization.string("\(host) doesn't allow forwarding to this port: \(sshMessage)")
        }
    }
}

enum LocalPortAvailability {
    /// Whether a forward can listen on 127.0.0.1 at `port`: binds it as `ssh` does, with `SO_REUSEADDR`, then lets go.
    static func isFree(_ port: Int) -> Bool {
        guard SSHPortForward.validPorts.contains(port) else { return false }
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        CloseOnExecDescriptor.mark(descriptor)
        defer { close(descriptor) }
        var reuse: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return bound == 0
    }
}
