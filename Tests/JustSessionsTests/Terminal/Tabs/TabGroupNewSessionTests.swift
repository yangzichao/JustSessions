import Foundation
import Testing

@testable import JustSessions

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
                engine: .swiftTerm,
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

        func launchNewSession(_ provider: ConversationProvider, inProjectOf tab: TerminalSession) {
            store.launchNewSessionFromProject(provider: provider, projectPath: tab.projectDirectoryKey)
        }

        func openPlainTerminal(inProjectOf tab: TerminalSession) {
            store.openPlainTerminal(in: ProjectLocation(key: tab.projectDirectoryKey))
        }

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

    @Test func aNewSessionFromAGroupsMenuJoinsItsGroupSelected() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let first = fixture.openTab(in: fixture.project)
        let other = fixture.openTab(in: fixture.otherProject)
        fixture.store.selectTerminal(other.id)

        fixture.launchNewSession(.codex, inProjectOf: first)

        let newTab = try fixture.newestTab(besides: [first, other])
        #expect(fixture.store.tabGroupKey(of: newTab) == fixture.store.tabGroupKey(of: first))
        #expect(newTab.provider == .codex)
        #expect(newTab.startsNewSession)
        #expect(fixture.store.selectedTerminalID == newTab.id)
        #expect(fixture.store.terminalSessions.map(\.id) == [first.id, newTab.id, other.id])
    }

    @Test func aTerminalFromAGroupsMenuJoinsItsGroupSelected() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let terminal = fixture.openTab(in: fixture.project, isPlainTerminal: true)
        let other = fixture.openTab(in: fixture.otherProject)

        fixture.openPlainTerminal(inProjectOf: terminal)

        let newTab = try fixture.newestTab(besides: [terminal, other])
        #expect(newTab.isPlainTerminal)
        #expect(fixture.store.tabGroupKey(of: newTab) == fixture.store.tabGroupKey(of: terminal))
        #expect(fixture.store.selectedTerminalID == newTab.id)

        fixture.launchNewSession(.codex, inProjectOf: terminal)

        let newSession = try fixture.newestTab(besides: [terminal, other, newTab])
        #expect(fixture.store.tabGroupKey(of: newSession) == fixture.store.tabGroupKey(of: terminal))
        #expect(fixture.store.selectedTerminalID == newSession.id)
    }

    @Test func aNewTabInTheProjectOfASplitsTabOpensInItsOwnProject() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let paper = fixture.openTab(in: fixture.project)
        let api = fixture.openTab(in: fixture.otherProject)
        store.selectTerminal(paper.id)
        store.splitSelectedTerminal(with: api.id)
        let splitGroupKey = store.tabGroupKey(of: api)
        try #require(splitGroupKey == store.tabGroupKey(of: paper))
        try #require(api.projectDirectoryKey != splitGroupKey)

        fixture.launchNewSession(.codex, inProjectOf: api)
        let newSession = try fixture.newestTab(besides: [paper, api])
        fixture.openPlainTerminal(inProjectOf: api)
        let newTerminal = try fixture.newestTab(besides: [paper, api, newSession])

        #expect(store.tabGroupKey(of: newSession) == api.projectDirectoryKey)
        #expect(store.tabGroupKey(of: newTerminal) == api.projectDirectoryKey)
        #expect(store.selectedTerminalID == newTerminal.id)
    }

    @Test func aNewTabInAnSSHHostsGroupOpensInItOnThatHost() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let remoteTab = TerminalSession(
            engine: .swiftTerm,
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

        fixture.launchNewSession(.claude, inProjectOf: remoteTab)
        let newSession = try fixture.newestTab(besides: [remoteTab, localTab])
        fixture.openPlainTerminal(inProjectOf: remoteTab)
        let newTerminal = try fixture.newestTab(besides: [remoteTab, localTab, newSession])

        for newTab in [newSession, newTerminal] {
            #expect(newTab.host == .ssh("devbox"))
            #expect(newTab.command.executablePath == "/usr/bin/ssh")
            #expect(store.tabGroupKey(of: newTab) == "ssh://devbox/home/me/paper")
        }
        #expect(store.terminalSessions.map(\.id) == [remoteTab.id, newSession.id, newTerminal.id, localTab.id])
        #expect(store.selectedTerminalID == newTerminal.id)
    }

    @Test func theMenuFollowsTheGroupsFolderAndHost() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let store = fixture.store
        let tab = fixture.openTab(in: fixture.project)
        #expect(ProjectLocation(key: tab.projectDirectoryKey).canStartSessions)

        store.setInstalledProviders([], on: .thisMac)
        #expect(store.newSessionProviders(on: ProjectLocation(key: tab.projectDirectoryKey).host).isEmpty)
        try FileManager.default.removeItem(at: fixture.project)
        #expect(!ProjectLocation(key: tab.projectDirectoryKey).canStartSessions)

        fixture.openPlainTerminal(inProjectOf: tab)
        #expect(store.terminalSessions.map(\.id) == [tab.id])
        #expect(store.errorMessage != nil)
    }
}
