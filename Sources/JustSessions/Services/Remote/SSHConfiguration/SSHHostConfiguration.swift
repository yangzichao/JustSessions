import Foundation

/// The settings `ssh` would connect to a host with, after `~/.ssh/config`, as `ssh -G` prints them. `ssh -G` reads
/// the config and exits without connecting, in a few milliseconds.
struct SSHHostConfiguration: Equatable, Sendable {
    /// Each setting's values, under its name in lowercase, as `ssh -G` prints them.
    let settings: [String: [String]]

    /// Nil when `ssh -G` failed, as for a destination it can't parse. `configFile` stands in for `~/.ssh/config`.
    static func resolve(host: String, configFile: String? = nil) -> SSHHostConfiguration? {
        guard let result = BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/ssh",
            arguments: (configFile.map { ["-F", $0] } ?? []) + ["-G", "--", host],
            environment: SSHProcessEnvironment.standard,
            timeout: 10
        ), result.exitStatus == 0 else { return nil }
        return SSHHostConfiguration(sshDashGOutput: result.output)
    }

    init(sshDashGOutput output: String) {
        settings = output.split(whereSeparator: \.isNewline).reduce(into: [String: [String]]()) { settings, line in
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { return }
            settings[parts[0].lowercased(), default: []].append(String(parts[1]))
        }
    }

    func value(of name: String) -> String? {
        settings[name]?.first
    }

    var user: String? { value(of: "user") }
    var hostName: String? { value(of: "hostname") }
    var port: String? { value(of: "port") }

    /// Where the user's own shared connections are kept, or nil when the config sets none.
    var controlPath: String? {
        guard let path = value(of: "controlpath"), path != "none" else { return nil }
        return path
    }
}
