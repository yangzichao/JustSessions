import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TerminalTabLinkOpeningTests {
    @Test func byDefaultAFileOpensInItsDefaultAppWithoutItsLine() throws {
        let scenario = try Scenario(files: ["plan.md"])
        defer { scenario.tearDown() }

        scenario.click("plan.md:12")
        scenario.click("https://example.com/docs")

        #expect(scenario.openedURLs == [scenario.url("plan.md"), URL(string: "https://example.com/docs")!])
        #expect(scenario.editorOpenings.isEmpty)
    }

    @Test func aTabOnAnSSHHostOpensWebPagesButNoPathsWhateverTheChoice() throws {
        let scenario = try Scenario(files: ["plan.md"], host: .ssh("devbox"), choice: .editor(name: "Zed"))
        defer { scenario.tearDown() }

        scenario.click("plan.md")
        scenario.click(scenario.url("plan.md").path)
        scenario.click("https://example.com/docs")

        #expect(scenario.openedURLs == [URL(string: "https://example.com/docs")!])
        #expect(scenario.editorOpenings.isEmpty)
        #expect(scenario.shownMenus.isEmpty)
    }

    @Test func withAnEditorChosenATextFileOpensInItAtItsLine() async throws {
        let scenario = try Scenario(files: ["Sources/main.swift"], choice: .editor(name: "Zed"))
        defer { scenario.tearDown() }

        scenario.click("Sources/main.swift:42:7")

        try await expectEventually { !scenario.editorOpenings.isEmpty }
        #expect(scenario.editorOpenings.map(\.editorName) == ["Zed"])
        #expect(
            scenario.editorOpenings.map(\.item) == [
                TerminalLinkLocalItem(
                    url: scenario.url("Sources/main.swift"), kind: .file, lineNumber: 42, columnNumber: 7
                )
            ])
        #expect(scenario.openedURLs.isEmpty)
    }

    @Test func withAnEditorChosenAnImageStillOpensInItsDefaultAppAndAFolderInTheFinder() throws {
        let scenario = try Scenario(files: ["screenshot.png", "Sources/main.swift"], choice: .editor(name: "Zed"))
        defer { scenario.tearDown() }

        scenario.click("screenshot.png")
        scenario.click("Sources/")
        scenario.click("https://example.com/docs")

        #expect(
            scenario.openedURLs.map(\.path) == [
                scenario.url("screenshot.png").path, scenario.url("Sources").path, "/docs",
            ])
        #expect(scenario.editorOpenings.isEmpty)
    }

    @Test func aChosenEditorThatIsNoLongerInstalledLeavesTheFileToItsDefaultApp() throws {
        let scenario = try Scenario(files: ["plan.md"], choice: .editor(name: "Sublime Text"))
        defer { scenario.tearDown() }

        scenario.click("plan.md")

        #expect(scenario.openedURLs == [scenario.url("plan.md")])
        #expect(scenario.editorOpenings.isEmpty)
    }

    @Test func aChosenEditorThatFailsToOpenTheFileSaysSo() async throws {
        let scenario = try Scenario(files: ["plan.md"], choice: .editor(name: "Zed"))
        defer { scenario.tearDown() }
        scenario.tab.linkOpener.openInEditor = { _, _ in throw ExternalEditorCommandLineToolError.failed("No window to open it in") }

        scenario.click("plan.md")

        try await expectEventually { scenario.fixture.store.alert != nil }
        #expect(scenario.fixture.store.alert?.message == "Could not open plan.md in Zed: No window to open it in")
    }

    @Test func askingEachTimeShowsTheLinksItemsOverTheTerminal() throws {
        let scenario = try Scenario(files: ["plan.md", "screenshot.png"], choice: .askEachTime)
        defer { scenario.tearDown() }

        scenario.click("plan.md:12")
        scenario.click("screenshot.png")

        #expect(
            scenario.shownMenus.map { TerminalContextMenuFixture.titles(of: $0.menu) } == [
                ["Open", "Open in", "Reveal in Finder", "Copy Path"],
                ["Open", "Open in", "Reveal in Finder", "Copy Path"],
            ])
        #expect(scenario.shownMenus.allSatisfy { $0.view === scenario.tab.terminalView })
        #expect(scenario.openedURLs.isEmpty)

        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Open", in: scenario.shownMenus[0].menu))
        #expect(scenario.openedURLs == [scenario.url("plan.md")])
    }

    @Test func askingEachTimeLeavesWebPagesAndFoldersAsTheyWere() throws {
        let scenario = try Scenario(files: ["Sources/main.swift"], choice: .askEachTime)
        defer { scenario.tearDown() }

        scenario.click("https://example.com/docs")
        scenario.click("Sources/")

        #expect(scenario.openedURLs.map(\.path) == ["/docs", scenario.url("Sources").path])
        #expect(scenario.shownMenus.isEmpty)
    }

    @Test func aTabShownInItsWindowHandsItsClickedLinksOver() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: .swiftTerm)
        var clickedLinks: [String] = []
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = NSHostingView(
            rootView: TerminalWorkspaceView(
                session: tab, isShown: true, isActive: false, onReconnect: nil, onCheckHost: nil, onFocus: {},
                makeContextMenu: { _ in NSMenu() },
                onOpenLink: { clickedLinks.append($0) }
            ))
        window.contentView?.layoutSubtreeIfNeeded()

        tab.terminalView.onOpenLink?("plan.md:12")
        window.contentView = nil

        #expect(clickedLinks == ["plan.md:12"])
    }
}

@MainActor
private final class Scenario {
    let fixture: TerminalContextMenuFixture
    let tab: TerminalSession
    let folder: URL
    private(set) var openedURLs: [URL] = []
    private(set) var editorOpenings: [(item: TerminalLinkLocalItem, editorName: String)] = []
    private(set) var shownMenus: [(menu: NSMenu, view: NSView)] = []
    private let isolatedUserDefaults: IsolatedUserDefaults
    private let settingsStore: FileLinkClickSettingsStore

    init(files: [String], host: SessionHost = .thisMac, choice: FileLinkClickChoice = .defaultApp) throws {
        folder = try makeTemporaryDirectory()
        for file in files {
            let url = folder.appendingPathComponent(file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }
        fixture = try TerminalContextMenuFixture()
        tab = fixture.openTab(engine: .swiftTerm, projectPath: folder.path, host: host)
        isolatedUserDefaults = try IsolatedUserDefaults()
        settingsStore = FileLinkClickSettingsStore(userDefaults: isolatedUserDefaults.userDefaults)
        settingsStore.setChoice(choice)
        tab.linkOpener.openURL = { [weak self] in self?.openedURLs.append($0) }
        tab.linkOpener.openInEditor = { [weak self] item, editor in self?.editorOpenings.append((item, editor.name)) }
    }

    func url(_ relativePath: String) -> URL {
        folder.appendingPathComponent(relativePath)
    }

    func click(_ link: String) {
        TerminalLinkActions(
            store: fixture.store,
            tab: tab,
            editorStore: Self.editorStore,
            fileLinkClickSettingsStore: settingsStore,
            popUpMenu: { [weak self] menu, view in self?.shownMenus.append((menu, view)) }
        ).openClicked(link)
    }

    func tearDown() {
        fixture.tearDown()
        isolatedUserDefaults.removeSuite()
        try? FileManager.default.removeItem(at: folder)
    }

    private static var editorStore: ExternalEditorStore {
        let installedApplications = [
            "dev.zed.Zed": URL(fileURLWithPath: "/Applications/Zed.app"),
            "com.microsoft.VSCode": URL(fileURLWithPath: "/Applications/Visual Studio Code.app"),
        ]
        return ExternalEditorStore(
            applicationURLForBundleIdentifier: { installedApplications[$0] },
            sshFolderCommandLineToolForApplication: { _ in nil }
        )
    }
}
