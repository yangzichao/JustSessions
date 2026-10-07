import Foundation
import Testing
@testable import JustSessions

/// A tab's right-click menu starts a new session or a plain terminal in the tab's group, so the new tab joins that
/// group and is selected.
@MainActor
struct TabGroupNewSessionTests {
    @MainActor
    private struct Fixture {
        let store: ConversationStore
        let project: URL
        let otherProject: URL
        private let root: URL
        private let settings: IsolatedUserDefaults

        init() throws {
            root = try makeTemporaryDirectory()
            project = root.appendingPathComponent("paper")
            otherProject = root.appendingPathComponent("api")
            let binaryDirectory = root.appendingPathComponent("bin")
            for directory in [project, otherProject, binaryDirectory] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try writeExecutableScript("#!/bin/sh\nexit 0\n", to: binaryDirectory.appendingPathComponent("codex"))
            settings = try IsolatedUserDefaults()
            store = ConversationStore(
                adapters: [],
                commandResolver: NativeCLICommandResolver(searchDirectories: [binaryDirectory.path]),
                userDefaults: settings.userDefaults,
                startsBackgroundPolling: false
            )
        }

        @discardableResult
        func openTab(in folder: URL, isPlainTerminal: Bool = false) -> TerminalSession {
            let tab = TerminalSession(
                conversation: nil,
                provider: isPlainTerminal ? nil : .claude,
                projectPath: folder.path,
                action: isPlainTerminal ? nil : .resume,
                displayTitle: folder.lastPathComponent,
                command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: folder.path, environment: [])
            )
            store.openTerminal(tab)
            return tab
        }

        /// The tab the store opened last, which it selects.
        func newestTab(besides earlierTabs: [TerminalSession]) throws -> TerminalSession {
            let earlierIDs = Set(earlierTabs.map(\.id))
            return try #require(store.terminalSessions.first { !earlierIDs.contains($0.id) })
        }

        func tearDown() {
            store.closeAllTerminals()
            settings.removeSuite()
            try? FileManager.default.removeItem(at: root)
        }
    }

    @Test func aNewSessionFromATabsMenuJoinsItsGroupSelected() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let first = fixture.openTab(in: fixture.project)
        let other = fixture.openTab(in: fixture.otherProject)
        fixture.store.selectTerminal(other.id)

        fixture.store.launchNewSession(provider: .codex, inGroupOf: first)

        let newTab = try fixture.newestTab(besides: [first, other])
        #expect(fixture.store.tabGroupKey(of: newTab) == fixture.store.tabGroupKey(of: first))
        #expect(newTab.provider == .codex)
        #expect(newTab.startsNewSession)
        #expect(fixture.store.selectedTerminalID == newTab.id)
        // At the end of its group, as new sessions open, before the other project's group.
        #expect(fixture.store.terminalSessions.map(\.id) == [first.id, newTab.id, other.id])
    }

    @Test func aTerminalFromAPlainTerminalsMenuJoinsItsGroupSelected() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let terminal = fixture.openTab(in: fixture.project, isPlainTerminal: true)
        let other = fixture.openTab(in: fixture.otherProject)

        fixture.store.openPlainTerminal(inGroupOf: terminal)

        let newTab = try fixture.newestTab(besides: [terminal, other])
        #expect(newTab.isPlainTerminal)
        #expect(fixture.store.tabGroupKey(of: newTab) == fixture.store.tabGroupKey(of: terminal))
        #expect(fixture.store.selectedTerminalID == newTab.id)

        fixture.store.launchNewSession(provider: .codex, inGroupOf: terminal)

        let newSession = try fixture.newestTab(besides: [terminal, other, newTab])
        #expect(fixture.store.tabGroupKey(of: newSession) == fixture.store.tabGroupKey(of: terminal))
        #expect(fixture.store.selectedTerminalID == newSession.id)
    }

    /// A tab from another project shows in the split's group, and so does what is started from its menu.
    @Test func aSplitsTabFromAnotherProjectStartsItsNewTabInTheSplitsGroup() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let paper = fixture.openTab(in: fixture.project)
        let api = fixture.openTab(in: fixture.otherProject)
        store.selectTerminal(paper.id)
        store.splitSelectedTerminal(with: api.id)
        let groupKey = store.tabGroupKey(of: paper)
        try #require(store.tabGroupKey(of: api) == groupKey)
        try #require(api.projectDirectoryKey != groupKey)

        store.launchNewSession(provider: .codex, inGroupOf: api)
        let newSession = try fixture.newestTab(besides: [paper, api])
        store.openPlainTerminal(inGroupOf: api)
        let newTerminal = try fixture.newestTab(besides: [paper, api, newSession])

        #expect(store.groupLocation(of: api) == ProjectLocation(key: groupKey))
        #expect(store.tabGroupKey(of: newSession) == groupKey)
        #expect(store.tabGroupKey(of: newTerminal) == groupKey)
        #expect(store.selectedTerminalID == newTerminal.id)
    }

    @Test func aNewTabFromAnSSHHostsTabOpensInItsGroupOnThatHost() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let remoteTab = TerminalSession(
            conversation: nil,
            provider: .claude,
            projectPath: "/home/me/paper",
            action: .resume,
            displayTitle: "Paper",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/", environment: []),
            host: .ssh("devbox")
        )
        store.openTerminal(remoteTab)
        let localTab = fixture.openTab(in: fixture.project)

        store.launchNewSession(provider: .claude, inGroupOf: remoteTab)
        let newSession = try fixture.newestTab(besides: [remoteTab, localTab])
        store.openPlainTerminal(inGroupOf: remoteTab)
        let newTerminal = try fixture.newestTab(besides: [remoteTab, localTab, newSession])

        for newTab in [newSession, newTerminal] {
            #expect(newTab.host == .ssh("devbox"))
            #expect(newTab.command.executablePath == "/usr/bin/ssh")
            #expect(store.tabGroupKey(of: newTab) == "ssh://devbox/home/me/paper")
        }
        #expect(store.terminalSessions.map(\.id) == [remoteTab.id, newSession.id, newTerminal.id, localTab.id])
        #expect(store.selectedTerminalID == newTerminal.id)
    }

    /// The menu's items follow the group: disabled once its folder is gone, and only the CLIs its host has.
    @Test func theMenuFollowsTheGroupsFolderAndHost() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let tab = fixture.openTab(in: fixture.project)
        #expect(store.groupLocation(of: tab).canStartSessions)

        store.setInstalledProviders([], on: .thisMac)
        #expect(store.newSessionProviders(on: store.groupLocation(of: tab).host).isEmpty)
        try FileManager.default.removeItem(at: fixture.project)
        #expect(!store.groupLocation(of: tab).canStartSessions)

        // The folder is gone: an error instead of a tab.
        store.openPlainTerminal(inGroupOf: tab)
        #expect(store.terminalSessions.map(\.id) == [tab.id])
        #expect(store.errorMessage != nil)
    }
}
