import Foundation
import Testing

@testable import JustSessions

/// Disconnect leaves an SSH host alone: it closes the host's tabs in every window, forgets what ran there, and keeps
/// the choice; the host is listed from its last copy and not refreshed until Connect, or using the host, connects it.
@MainActor
struct RemoteHostDisconnectTests {
    @Test func disconnectingWithNoTabOpenAsksNothingAndMarksTheHostInEveryWindowForGood() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        for store in [sandbox.first, sandbox.second] { store.remoteHostList = RemoteHostList(hosts: ["devbox"]) }

        sandbox.second.requestDisconnect("devbox", tabCloseChoices: TabCloseChoicesByHost(), plainTerminalCloseChoice: .askEachTime)

        #expect(sandbox.second.hostDisconnectQuestion == nil)
        for store in [sandbox.first, sandbox.second] { #expect(store.isDisconnected("devbox")) }
        #expect(DisconnectedRemoteHosts.load(from: sandbox.first.userDefaults).isDisconnected("devbox"))
    }

    @Test func disconnectingAsksOnceAboutTheTabsOfEveryWindowThenClosesThemAndForgetsWhatRan() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.listSSHSession()
        let other = Conversation.fixture(projectPath: "/srv/other", host: .ssh("devbox"))
        for store in [sandbox.first, sandbox.second] {
            store.remoteHostList = RemoteHostList(hosts: ["devbox"])
            store.replaceConversations(on: .ssh("devbox"), with: [conversation, other])
            store.tmuxSessionNamesByHost[.ssh("devbox")] = [TmuxSessionName.forConversation(other)]
            store.detachedCLIActivities[other.id] = .working
        }
        let first = try #require(sandbox.openTab(of: conversation, in: sandbox.first))
        let second = try #require(sandbox.openTab(of: other, in: sandbox.second))

        sandbox.first.requestDisconnect("devbox", tabCloseChoices: TabCloseChoicesByHost(), plainTerminalCloseChoice: .askEachTime)

        #expect(sandbox.first.hostDisconnectQuestion?.question == .keepOrEndCLIs(alsoStopsOthers: false))
        #expect(!sandbox.first.isDisconnected("devbox"))
        #expect(sandbox.first.terminalSessions.map(\.id) == [first.id])

        sandbox.first.disconnectHost("devbox", endingTmuxSessions: false, connections: SSHLoginConnections(close: { _, _ in }))

        #expect(sandbox.first.hostDisconnectQuestion == nil)
        for store in [sandbox.first, sandbox.second] {
            #expect(store.isDisconnected("devbox"))
            #expect(store.terminalSessions.isEmpty)
            #expect(store.tmuxSessionNamesByHost[.ssh("devbox"), default: []].isEmpty)
            #expect(store.detachedCLIActivities.isEmpty)
        }
        #expect(first.connectionEndedOnPurpose)
        #expect(second.connectionEndedOnPurpose)
    }

    /// Each tab closes as its host's saved choice says, so nothing asks.
    @Test func aSavedCloseChoiceDisconnectsAtOnce() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.listSSHSession()
        for store in [sandbox.first, sandbox.second] { store.remoteHostList = RemoteHostList(hosts: ["devbox"]) }
        _ = try #require(sandbox.openTab(of: conversation, in: sandbox.second))

        sandbox.first.requestDisconnect(
            "devbox",
            tabCloseChoices: TabCloseChoicesByHost(sshHostChoices: ["devbox": .keepRunning]),
            plainTerminalCloseChoice: .askEachTime
        )

        #expect(sandbox.first.hostDisconnectQuestion == nil)
        #expect(sandbox.first.isDisconnected("devbox"))
        #expect(sandbox.second.terminalSessions.isEmpty)
    }

    @Test func aDisconnectedHostIsListedFromItsLastCopyAndNotRefreshed() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"))
        let project = mirror.mirrorDirectory(host: "devbox", provider: .claude).appendingPathComponent("projects/-srv-app")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString.lowercased()
        try #"{"type":"user","cwd":"/srv/app","message":{"content":"Draft intro"}}"#
            .appending("\n")
            .write(to: project.appendingPathComponent("\(sessionID).jsonl"), atomically: true, encoding: .utf8)
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        store.remoteHostList = RemoteHostList(hosts: ["devbox"])
        store.disconnectedRemoteHosts.setDisconnected(true, for: "devbox")
        store.remoteSessionDiscovery = RemoteSessionDiscovery(mirror: mirror)

        #expect(store.refreshRemoteHost("devbox") == .refused(.hostDisconnected))
        store.refresh(.ssh("devbox"))

        try await expectEventually { store.conversations.contains { $0.sessionID == sessionID && $0.host == .ssh("devbox") } }
        #expect(store.hostRefreshStatuses[.ssh("devbox")] == nil)
    }

    @Test func connectingRefreshesTheHostInEveryWindowAndForgetsTheChoice() async throws {
        let sandbox = try TwoWindowSandbox(remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }))
        defer { sandbox.tearDown() }
        let discovery = try Self.discoveryThatFailsWithoutSSH()
        for store in [sandbox.first, sandbox.second] {
            store.remoteHostList = RemoteHostList(hosts: ["devbox"])
            store.remoteSessionDiscovery = discovery
            store.disconnectedRemoteHosts.setDisconnected(true, for: "devbox")
        }
        DisconnectedRemoteHosts(hosts: ["devbox"]).save(to: sandbox.first.userDefaults)

        sandbox.second.connectHost("devbox")

        for store in [sandbox.first, sandbox.second] {
            #expect(!store.isDisconnected("devbox"))
            #expect(store.hostRefreshStatuses[.ssh("devbox")] == .refreshing)
        }
        #expect(!DisconnectedRemoteHosts.load(from: sandbox.first.userDefaults).isDisconnected("devbox"))
        try await expectEventually {
            [sandbox.first, sandbox.second].allSatisfy { $0.hostRefreshStatuses[.ssh("devbox")] != .refreshing }
        }
    }

    /// Resuming a session there, as starting one or deleting there, is using the host, which connects it.
    @Test func usingADisconnectedHostConnectsIt() async throws {
        let sandbox = try TwoWindowSandbox(remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }))
        defer { sandbox.tearDown() }
        let conversation = sandbox.listSSHSession()
        let discovery = try Self.discoveryThatFailsWithoutSSH()
        for store in [sandbox.first, sandbox.second] {
            store.remoteHostList = RemoteHostList(hosts: ["devbox"])
            store.remoteSessionDiscovery = discovery
            store.disconnectedRemoteHosts.setDisconnected(true, for: "devbox")
        }

        let tab = sandbox.openTab(of: conversation, in: sandbox.first)

        #expect(tab != nil)
        for store in [sandbox.first, sandbox.second] { #expect(!store.isDisconnected("devbox")) }
        #expect(sandbox.first.hostRefreshStatuses[.ssh("devbox")] == .refreshing)
        try await expectEventually {
            [sandbox.first, sandbox.second].allSatisfy { $0.hostRefreshStatuses[.ssh("devbox")] != .refreshing }
        }
    }

    @Test func removingTheHostForgetsTheChoice() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        store.remoteHostList = RemoteHostList(hosts: ["devbox"])
        store.requestDisconnect("devbox", tabCloseChoices: TabCloseChoicesByHost(), plainTerminalCloseChoice: .askEachTime)
        #expect(DisconnectedRemoteHosts.load(from: settings.userDefaults).isDisconnected("devbox"))

        store.removeRemoteHost("devbox", mirror: RemoteSessionMirror(cacheRoot: root))

        #expect(!store.isDisconnected("devbox"))
        #expect(!DisconnectedRemoteHosts.load(from: settings.userDefaults).isDisconnected("devbox"))
    }

    /// Its copy's folder is a file, so the refresh fails before it would run `ssh`.
    private static func discoveryThatFailsWithoutSSH() throws -> RemoteSessionDiscovery {
        let notAFolder = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-folder-\(UUID().uuidString.prefix(8))")
        try "".write(to: notAFolder, atomically: true, encoding: .utf8)
        return RemoteSessionDiscovery(
            mirror: RemoteSessionMirror(
                cacheRoot: notAFolder,
                sourceHomeOverride: FileManager.default.temporaryDirectory.path
            ))
    }
}
