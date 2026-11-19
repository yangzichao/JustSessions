import Foundation
import Testing

@testable import JustSessions

/// Runs the real `/usr/bin/ssh -G`, which reads the config and exits without connecting.
struct SSHHostConfigurationTests {
    static let config = """
        Host devbox
          HostName 192.0.2.10
          User me
          Port 2222

        Host shared
          HostName 192.0.2.11
          ControlMaster auto
          ControlPath ~/.ssh/cm-%C

        Host unshared
          HostName 192.0.2.12
          ControlPath none

        """

    @Test func readsWhereTheHostLeads() throws {
        let configuration = try #require(try Self.resolve("devbox"))

        #expect(configuration.user == "me")
        #expect(configuration.hostName == "192.0.2.10")
        #expect(configuration.port == "2222")
        #expect(configuration.controlPath == nil)
    }

    @Test func aDestinationOutsideTheConfigIsReadAsTyped() throws {
        let configuration = try #require(try Self.resolve("Root@Example.COM"))

        #expect(configuration.user == "Root")
        #expect(configuration.hostName == "example.com")
        #expect(configuration.port == "22")
    }

    @Test func readsTheUsersOwnControlPath() throws {
        let shared = try #require(try Self.resolve("shared"))
        let unshared = try #require(try Self.resolve("unshared"))

        #expect(shared.controlPath?.hasPrefix(NSHomeDirectory() + "/.ssh/cm-") == true)
        #expect(unshared.controlPath == nil)
    }

    @Test func connectionSharingFallbackPreservesAliasesAndExplicitPolicies() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let configFile = root.appendingPathComponent("config")
        try """
        Host allowed
          HostName 192.0.2.20
          User deploy
          Port 2202
          ProxyJump gateway
          StrictHostKeyChecking yes
        Host disabled
          ControlMaster no
        Host own-path
          ControlMaster auto
          ControlPath ~/.ssh/own-%C
        Host no-path
          ControlPath none
        Host no-persist
          ControlPersist no

        """.write(to: configFile, atomically: true, encoding: .utf8)
        let fallbackPath = "/tmp/justsessions-test/master"
        func resolve(_ host: String) -> SSHHostConfiguration? {
            SSHHostConfiguration.resolveWithConnectionSharingFallback(
                host: host,
                controlPath: fallbackPath,
                userConfigFile: configFile.path,
                systemConfigFile: root.appendingPathComponent("missing-system-config").path
            )
        }

        let allowed = try #require(resolve("allowed"))
        #expect(allowed.controlMaster == "auto")
        #expect(allowed.controlPath == fallbackPath)
        #expect(allowed.controlPersist == "60")
        #expect(allowed.hostName == "192.0.2.20")
        #expect(allowed.user == "deploy")
        #expect(allowed.port == "2202")
        #expect(allowed.value(of: "proxyjump") == "gateway")
        #expect(allowed.value(of: "stricthostkeychecking") == "true")

        #expect(try #require(resolve("disabled")).controlMaster == "false")
        #expect(try #require(resolve("own-path")).controlPath != fallbackPath)
        #expect(try #require(resolve("no-path")).controlPath == nil)
        #expect(try #require(resolve("no-persist")).controlPersist == "no")
    }

    @Test func connectionSharingFallbackReadsSystemPolicyAfterANonmatchingUserBlock() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let userConfig = root.appendingPathComponent("user-config")
        try """
        Host another-host
          HostName 192.0.2.30

        """.write(to: userConfig, atomically: true, encoding: .utf8)
        let systemConfig = root.appendingPathComponent("system-config")
        try """
        Host devbox
          ControlMaster no
          ControlPath none
          ControlPersist no

        """.write(to: systemConfig, atomically: true, encoding: .utf8)

        let configuration = try #require(
            SSHHostConfiguration.resolveWithConnectionSharingFallback(
                host: "devbox",
                controlPath: "/tmp/justsessions-test/master",
                userConfigFile: userConfig.path,
                systemConfigFile: systemConfig.path
            ))

        #expect(configuration.controlMaster == "false")
        #expect(configuration.controlPath == nil)
        #expect(configuration.controlPersist == "no")
    }

    @Test func aDestinationSSHCanNotParseHasNoConfiguration() throws {
        #expect(try Self.resolve("-oProxyCommand=touch /tmp/x") == nil)
    }

    @Test func keepsEveryValueOfARepeatedSetting() {
        let configuration = SSHHostConfiguration(sshDashGOutput: "localforward 1 [a]:1\nlocalforward 2 [b]:2\nport 22\n")

        #expect(configuration.settings["localforward"] == ["1 [a]:1", "2 [b]:2"])
        #expect(configuration.port == "22")
    }

    private static func resolve(_ host: String) throws -> SSHHostConfiguration? {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let configFile = root.appendingPathComponent("config")
        try config.write(to: configFile, atomically: true, encoding: .utf8)
        return SSHHostConfiguration.resolve(host: host, configFile: configFile.path)
    }
}
