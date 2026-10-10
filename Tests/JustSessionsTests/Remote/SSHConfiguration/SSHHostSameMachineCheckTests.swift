import Foundation
import Testing
@testable import JustSessions

struct SSHHostSameMachineCheckTests {
    static let config = """
        Host devbox
          HostName 192.0.2.10
          User me

        Host devbox-again
          HostName 192.0.2.10
          User me
          IdentityFile ~/.ssh/other-key

        Host behind-bastion
          HostName 192.0.2.10
          User me
          ProxyJump bastion

        Host devbox-2222
          HostName 192.0.2.10
          User me
          Port 2222

        """

    @Test(arguments: ["devbox-again", "me@192.0.2.10", "me@devbox"])
    func findsTheListedHostThatConnectsToTheSamePlace(host: String) throws {
        let check = try Self.check(host: host, listedHosts: ["other", "devbox"])

        #expect(check.listedHostWithSameIdentity == "devbox")
        #expect(check.identity?.userAtHostName == "me@192.0.2.10")
    }

    /// `ssh` matches `Host` names and keeps user names as typed, so `Devbox` is the machine DNS calls devbox, and
    /// `ME@devbox` another account.
    @Test(arguments: ["behind-bastion", "devbox-2222", "root@192.0.2.10", "192.0.2.11", "Devbox", "ME@devbox"])
    func anotherJumpHostPortOrAccountIsAnotherHost(host: String) throws {
        #expect(try Self.check(host: host, listedHosts: ["devbox"]).listedHostWithSameIdentity == nil)
    }

    @Test func showsTheNonStandardPort() throws {
        let identity = try #require(try Self.check(host: "devbox-2222", listedHosts: []).identity)

        #expect(identity.nonStandardPort == "2222")
        #expect(try Self.check(host: "devbox", listedHosts: []).identity?.nonStandardPort == nil)
    }

    @Test func aHostSSHCanNotReadHasNoIdentity() {
        let check = SSHHostSameMachineCheck.check(host: "devbox", listedHosts: ["devbox-again"], resolve: { _ in nil })

        #expect(check == SSHHostSameMachineCheck(identity: nil, listedHostWithSameIdentity: nil))
    }

    private static func check(host: String, listedHosts: [String]) throws -> SSHHostSameMachineCheck {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let configFile = root.appendingPathComponent("config")
        try config.write(to: configFile, atomically: true, encoding: .utf8)
        return SSHHostSameMachineCheck.check(host: host, listedHosts: listedHosts) {
            SSHHostConfiguration.resolve(host: $0, configFile: configFile.path).flatMap(SSHHostIdentity.init)
        }
    }
}
