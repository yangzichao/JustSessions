import AppKit
import Testing
@testable import JustSessions

/// A right-click on a link starts the terminal's menu with what to do with it; see `TerminalLinkActions`. Both
/// engines hand the menu the same link (`TerminalLinkRightClickTests`), so these build the menu with it directly.
@MainActor
@Suite(.serialized)
struct TerminalContextMenuLinkTests {
    private static let textAndTabItems = [
        "Copy", "Paste", "Select All", "—", "Rename", "—", "Split right", "Split down", "—",
        "Close Tab…", "Close and end session",
    ]

    @Test func offAnyLinkTheMenuIsUnchanged() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: .swiftTerm)

        #expect(titles(fixture.menu(for: tab, linkUnderPointer: nil)) == Self.textAndTabItems)
        #expect(titles(fixture.menu(for: tab, linkUnderPointer: "Sources/missing.swift:3")) == Self.textAndTabItems)
    }

    @Test func aWebLinkOpensOrIsCopied() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: .swiftTerm)
        let actions = LinkActionRecorder(tab)
        let menu = fixture.menu(for: tab, linkUnderPointer: "https://example.com/docs")

        #expect(titles(menu) == ["Open Link", "Copy Link", "—"] + Self.textAndTabItems)
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Open Link", in: menu))
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Copy Link", in: menu))

        #expect(actions.openedURLs == [URL(string: "https://example.com/docs")!])
        #expect(actions.copiedTexts == ["https://example.com/docs"])
    }

    @Test func aFileOpensInItsAppOrAnEditorShowsInTheFinderOrHasItsPathCopied() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let project = try TemporaryProject(files: ["plan.md"])
        defer { project.remove() }
        let tab = fixture.openTab(engine: .swiftTerm, projectPath: project.folder.path)
        let actions = LinkActionRecorder(tab)
        let menu = fixture.menu(for: tab, linkUnderPointer: "plan.md:12:3", editorStore: Self.editorStore)
        let plan = project.folder.appendingPathComponent("plan.md")

        #expect(titles(menu) == ["Open", "Open in", "Reveal in Finder", "Copy Path", "—"] + Self.textAndTabItems)
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Open", in: menu))
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Reveal in Finder", in: menu))
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Copy Path", in: menu))

        #expect(actions.openedURLs == [plan])
        #expect(actions.revealedURLs == [plan])
        #expect(actions.copiedTexts == [plan.path])
    }

    @Test func aFileOpensInAnEditorAtItsLine() async throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let project = try TemporaryProject(files: ["plan.md"])
        defer { project.remove() }
        let tab = fixture.openTab(engine: .swiftTerm, projectPath: project.folder.path)
        let actions = LinkActionRecorder(tab)
        let editors = try #require(
            TerminalContextMenuFixture.item("Open in", in: fixture.menu(for: tab, linkUnderPointer: "plan.md:12:3", editorStore: Self.editorStore))
                .submenu
        )

        #expect(titles(editors) == ["Visual Studio Code", "Zed"])
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Zed", in: editors))

        try await expectEventually { !actions.editorOpenings.isEmpty }
        #expect(actions.editorOpenings.map(\.editorName) == ["Zed"])
        #expect(actions.editorOpenings.map(\.item) == [TerminalLinkLocalItem(
            url: project.folder.appendingPathComponent("plan.md"), kind: .file, lineNumber: 12, columnNumber: 3
        )])
    }

    @Test func anEditorThatFailsToOpenTheFileSaysSo() async throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let project = try TemporaryProject(files: ["plan.md"])
        defer { project.remove() }
        let tab = fixture.openTab(engine: .swiftTerm, projectPath: project.folder.path)
        tab.linkOpener.openInEditor = { _, _ in throw ExternalEditorCommandLineToolError.failed("No window to open it in") }
        let editors = try #require(
            TerminalContextMenuFixture.item("Open in", in: fixture.menu(for: tab, linkUnderPointer: "plan.md", editorStore: Self.editorStore))
                .submenu
        )

        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Zed", in: editors))

        try await expectEventually { fixture.store.alert != nil }
        #expect(fixture.store.alert?.message == "Could not open plan.md in Zed: No window to open it in")
    }

    /// Opening would run it; an editor or the Finder only shows it.
    @Test func aFileThatOpeningWouldRunDoesNotOpen() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let project = try TemporaryProject(files: ["install.command"])
        defer { project.remove() }
        let tab = fixture.openTab(engine: .swiftTerm, projectPath: project.folder.path)

        #expect(titles(fixture.menu(for: tab, linkUnderPointer: "install.command", editorStore: Self.editorStore))
            == ["Open in", "Reveal in Finder", "Copy Path", "—"] + Self.textAndTabItems)
    }

    @Test func aFolderOpensInTheFinderOrAnEditor() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let project = try TemporaryProject(files: ["Sources/main.swift"])
        defer { project.remove() }
        let tab = fixture.openTab(engine: .swiftTerm, projectPath: project.folder.path)
        let actions = LinkActionRecorder(tab)
        let menu = fixture.menu(for: tab, linkUnderPointer: "Sources/", editorStore: Self.editorStore)

        #expect(titles(menu) == ["Open in Finder", "Open in", "Copy Path", "—"] + Self.textAndTabItems)
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Open in Finder", in: menu))

        #expect(actions.openedURLs.map(\.path) == [project.folder.appendingPathComponent("Sources").path])
    }

    @Test func withoutEditorsThereIsNoOpenIn() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let project = try TemporaryProject(files: ["plan.md"])
        defer { project.remove() }
        let tab = fixture.openTab(engine: .swiftTerm, projectPath: project.folder.path)

        #expect(titles(fixture.menu(for: tab, linkUnderPointer: "plan.md"))
            == ["Open", "Reveal in Finder", "Copy Path", "—"] + Self.textAndTabItems)
    }

    /// The file is on the host, so only its path can be copied.
    @Test func aPathInATabOnAnSSHHostCanOnlyBeCopied() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let tab = fixture.openTab(engine: .swiftTerm, host: .ssh("devbox"))
        let actions = LinkActionRecorder(tab)
        let menu = fixture.menu(for: tab, linkUnderPointer: "Sources/App/main.swift:42", editorStore: Self.editorStore)

        #expect(titles(menu) == ["Copy Path", "—"] + Self.textAndTabItems)
        try TerminalContextMenuFixture.choose(TerminalContextMenuFixture.item("Copy Path", in: menu))

        #expect(actions.copiedTexts == ["Sources/App/main.swift"])
    }

    @Test func theLinkItemsAreInTheAppsLanguage() throws {
        let fixture = try TerminalContextMenuFixture()
        defer { fixture.tearDown() }
        let project = try TemporaryProject(files: ["plan.md"])
        defer { project.remove() }
        let tab = fixture.openTab(engine: .swiftTerm, projectPath: project.folder.path)

        let fileMenu = fixture.menu(for: tab, language: "zh-Hans", linkUnderPointer: "plan.md", editorStore: Self.editorStore)
        let webMenu = fixture.menu(for: tab, language: "zh-Hans", linkUnderPointer: "https://example.com")

        #expect(titles(fileMenu).prefix(4) == ["打开", "打开方式", "在 Finder 中显示", "复制路径"])
        #expect(titles(webMenu).prefix(2) == ["打开链接", "复制链接"])
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

    private func titles(_ menu: NSMenu) -> [String] {
        TerminalContextMenuFixture.titles(of: menu)
    }
}

/// Records what a tab's link items did, in place of opening, showing, or copying anything.
@MainActor
private final class LinkActionRecorder {
    private(set) var openedURLs: [URL] = []
    private(set) var revealedURLs: [URL] = []
    private(set) var copiedTexts: [String] = []
    private(set) var editorOpenings: [(item: TerminalLinkLocalItem, editorName: String)] = []

    init(_ tab: TerminalSession) {
        tab.linkOpener.openURL = { [weak self] in self?.openedURLs.append($0) }
        tab.linkOpener.revealInFinder = { [weak self] in self?.revealedURLs.append($0) }
        tab.linkOpener.copyText = { [weak self] in self?.copiedTexts.append($0) }
        tab.linkOpener.openInEditor = { [weak self] item, editor in self?.editorOpenings.append((item, editor.name)) }
    }
}

/// A project folder with empty files at the given relative paths.
private struct TemporaryProject {
    let folder: URL

    init(files: [String]) throws {
        folder = try makeTemporaryDirectory()
        for file in files {
            let url = folder.appendingPathComponent(file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: folder)
    }
}
