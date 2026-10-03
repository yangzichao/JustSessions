import Foundation
import Testing
@testable import JustSessions

@MainActor
struct InstalledCLIsTests {
    @Test func findsOnlyTheCLIsOnTheSearchPath() throws {
        let binaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: binaryDirectory) }
        for executableName in ["pi", "kiro-cli"] {
            try writeExecutableScript("#!/bin/sh\nexit 0\n", to: binaryDirectory.appendingPathComponent(executableName))
        }
        try "not executable".write(to: binaryDirectory.appendingPathComponent("opencode"), atomically: true, encoding: .utf8)

        let resolver = NativeCLICommandResolver(searchDirectories: [binaryDirectory.path])

        #expect(InstalledCLIs.onThisMac(commandResolver: resolver) == [.kiro, .pi])
    }

    @Test func newSessionsOfferEveryToolUntilTheHostIsCheckedThenOnlyInstalledOnes() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        RemoteHostList(hosts: ["devbox"]).save(to: isolatedUserDefaults.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        #expect(store.newSessionProviders(on: .thisMac) == ConversationProvider.allCases)
        #expect(store.newSessionProviders(on: .ssh("devbox")) == ConversationProvider.allCases)

        store.setInstalledProviders([.pi, .claude], on: .thisMac)
        store.setInstalledProviders([.codex, .pi], on: .ssh("devbox"))
        store.setInstalledProviders([.claude], on: .ssh("unlisted"))

        #expect(store.newSessionProviders(on: .thisMac) == [.claude, .pi])
        #expect(store.newSessionProviders(on: .ssh("devbox")) == [.codex, .pi])
        #expect(store.newSessionProvidersByHost == [.thisMac: [.claude, .pi], .ssh("devbox"): [.codex, .pi]])
        #expect(store.installedProvidersByHost[.ssh("unlisted")] == nil)

        store.setInstalledProviders([], on: .thisMac)
        #expect(store.newSessionProviders(on: .thisMac).isEmpty)
    }

    @Test func filterOffersInstalledToolsAndToolsWithListedSessions() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        store.setInstalledProviders([.claude, .opencode], on: .thisMac)
        store.replaceConversations(on: .thisMac, with: [.fixture(provider: .antigravity)])

        #expect(store.filterableProviders == [.claude, .opencode, .antigravity])
    }

    @Test func noCLIMessageNamesEveryToolThatRunsOnTheHost() {
        #expect(NewSessionProviderAvailability.noCLIFoundMessage(on: .ssh("devbox"))
            == "No supported CLI found on devbox. Install claude, codex, agy, kiro-cli, opencode, or pi there, then refresh.")
        #expect(NewSessionProviderAvailability.noCLIFoundMessage(on: .thisMac).contains("kiro-cli"))
    }
}
