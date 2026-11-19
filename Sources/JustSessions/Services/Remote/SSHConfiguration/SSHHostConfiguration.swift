import Foundation

struct SSHHostConfiguration: Equatable, Sendable {
    let settings: [String: [String]]

    static func resolve(host: String, configFile: String? = nil) -> SSHHostConfiguration? {
        resolve(host: host, arguments: configFile.map { ["-F", $0] } ?? [])
    }

    /// Resolves the user's settings before fallback connection-sharing settings. OpenSSH keeps the first value it
    /// reads, so an explicit `ControlMaster no`, `ControlPath none`, or a control path of the user's own wins; only
    /// an otherwise-unset host receives both fallbacks. The resulting connection still uses the regular config.
    static func resolveWithConnectionSharingFallback(
        host: String,
        controlPath: String,
        userConfigFile: String = NSHomeDirectory() + "/.ssh/config",
        systemConfigFile: String = "/etc/ssh/ssh_config"
    ) -> SSHHostConfiguration? {
        let probe = FileManager.default.temporaryDirectory
            .appendingPathComponent("justsessions-ssh-config-\(UUID().uuidString)")
        let contents = """
            Include \(quotedConfigPath(userConfigFile))
            Host *
            Include \(quotedConfigPath(systemConfigFile))
            Host *
              ControlMaster auto
              ControlPath \(quotedConfigPath(controlPath))
              ControlPersist \(SSHConnectionSharing.crashFallbackSeconds)

            """
        do { try contents.write(to: probe, atomically: true, encoding: .utf8) } catch { return nil }
        defer { try? FileManager.default.removeItem(at: probe) }
        return resolve(host: host, arguments: ["-F", probe.path])
    }

    private static func resolve(host: String, arguments: [String]) -> SSHHostConfiguration? {
        guard
            let result = BoundedProcessRunner.result(
                ofExecutable: "/usr/bin/ssh",
                arguments: arguments + ["-G", "--", host],
                environment: SSHProcessEnvironment.standard,
                timeout: 10
            ), result.exitStatus == 0
        else { return nil }
        return SSHHostConfiguration(sshDashGOutput: result.output)
    }

    private static func quotedConfigPath(_ path: String) -> String {
        "\"" + path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
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
    var controlMaster: String? { value(of: "controlmaster") }
    var controlPersist: String? { value(of: "controlpersist") }

    var controlPath: String? {
        guard let path = value(of: "controlpath"), path != "none" else { return nil }
        return path
    }
}
