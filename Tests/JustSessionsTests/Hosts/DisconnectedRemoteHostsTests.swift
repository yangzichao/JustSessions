import Foundation
import Testing

@testable import JustSessions

struct DisconnectedRemoteHostsTests {
    @Test func theChoiceIsSavedAndLoadedPerHost() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        var hosts = DisconnectedRemoteHosts.load(from: settings.userDefaults)
        #expect(hosts.hosts.isEmpty)

        hosts.setDisconnected(true, for: "devbox")
        hosts.setDisconnected(true, for: "buildbox")
        hosts.setDisconnected(false, for: "buildbox")
        hosts.save(to: settings.userDefaults)

        let loaded = DisconnectedRemoteHosts.load(from: settings.userDefaults)
        #expect(loaded.isDisconnected("devbox"))
        #expect(!loaded.isDisconnected("buildbox"))
        #expect(loaded == DisconnectedRemoteHosts(hosts: ["devbox"]))
    }
}
