import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct ConversationMapColumnTests {
    @MainActor
    private final class Fixture {
        static let windowWidth: CGFloat = 700
        let settings: IsolatedUserDefaults
        let store: ConversationStore
        let window: NSWindow
        let tab: TerminalSession

        init(provider: ConversationProvider? = .codex, conversation: Conversation? = nil, isShown: Bool = true) throws {
            _ = NSApplication.shared
            WindowAnimations.disable()
            settings = try IsolatedUserDefaults()
            store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
            tab = TerminalSession(
                engine: .swiftTerm,
                conversation: conversation,
                provider: provider,
                projectPath: "/tmp/conversation-map",
                action: provider == nil ? nil : .resume,
                displayTitle: "Conversation map",
                command: NativeCLICommand(executablePath: "/bin/cat", arguments: [], workingDirectory: "/tmp", environment: [])
            )
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: Self.windowWidth, height: 400), styleMask: [.titled, .miniaturizable],
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: TerminalWorkspaceView(
                    session: tab,
                    isShown: isShown,
                    isActive: true,
                    onReconnect: nil,
                    onCheckHost: nil,
                    onFocus: {},
                    makeContextMenu: { _ in NSMenu() },
                    onOpenLink: { _ in },
                    store: store
                )
                .defaultAppStorage(settings.userDefaults)
                .environment(\.ignoresWindowOcclusion, true))
            window.makeKeyAndOrderFront(nil)
            window.contentView?.layoutSubtreeIfNeeded()
        }

        var fullTerminalWidth: CGFloat {
            Self.windowWidth - TerminalInsetView.insets.left - TerminalInsetView.insets.right - tab.terminalView.trailingMarginWidth
        }

        var terminalWidth: CGFloat {
            window.contentView?.layoutSubtreeIfNeeded()
            return tab.terminalView.frame.width
        }

        func showMap(_ isShown: Bool) {
            settings.userDefaults.set(isShown, forKey: ConversationMapVisibility.userDefaultsKey)
        }

        func tearDown() {
            tab.close()
            window.contentView = nil
            window.close()
            settings.removeSuite()
        }
    }

    @Test func theMapIsOffUntilTurnedOn() async throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }

        try await expectEventually { fixture.terminalWidth == fixture.fullTerminalWidth }
        try await Task.sleep(for: .milliseconds(100))
        #expect(fixture.terminalWidth == fixture.fullTerminalWidth)
    }

    @Test func aCLITabNarrowsByTheColumnOnlyWhileTheMapIsOn() async throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        try await expectEventually { fixture.terminalWidth == fixture.fullTerminalWidth }

        fixture.showMap(true)
        try await expectEventually { fixture.terminalWidth == fixture.fullTerminalWidth - ConversationMapMetrics.columnWidth }

        fixture.showMap(false)
        try await expectEventually { fixture.terminalWidth == fixture.fullTerminalWidth }
    }

    @Test func aPlainTerminalHasNoColumn() async throws {
        let fixture = try Fixture(provider: nil)
        defer { fixture.tearDown() }
        fixture.showMap(true)

        try await expectEventually { fixture.terminalWidth == fixture.fullTerminalWidth }
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.terminalWidth == fixture.fullTerminalWidth)
    }

    @Test func linkingATabDoesNotResizeItsTerminal() async throws {
        let files = try TranscriptPagingFixture(count: 5)
        defer { files.remove() }
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        fixture.showMap(true)
        let narrowed = fixture.fullTerminalWidth - ConversationMapMetrics.columnWidth
        try await expectEventually { fixture.terminalWidth == narrowed }
        var widths: [CGFloat] = []

        fixture.tab.synchronize(conversation: files.conversation, displayTitle: "Linked")

        try await expectEventually {
            widths.append(fixture.terminalWidth)
            return fixture.tab.conversationOutline.outline?.blocks.count == 5
        }
        #expect(fixture.terminalWidth == narrowed)
        #expect(widths.allSatisfy { $0 == narrowed })
    }

    @Test func aHiddenTabDoesNoOutlineWork() async throws {
        let files = try TranscriptPagingFixture(count: 5)
        defer { files.remove() }
        let fixture = try Fixture(conversation: files.conversation, isShown: false)
        defer { fixture.tearDown() }
        fixture.showMap(true)
        try await expectEventually { fixture.terminalWidth == fixture.fullTerminalWidth - ConversationMapMetrics.columnWidth }

        try await Task.sleep(for: .milliseconds(300))

        #expect(fixture.tab.conversationOutline.readCount == 0)
        #expect(fixture.tab.conversationOutline.outline == nil)
    }

    /// PERF-89: only a map on screen checks its file. A test process gets no occlusion from macOS, so a covered window is
    /// checked by hand; a minimized one counts whatever the occlusion. Waits past the 1-second check and 2-second read
    /// spacing of this Mac before calling the append unread.
    @Test func aMinimizedWindowsMapReadsNothingUntilItComesBack() async throws {
        let files = try TranscriptPagingFixture(count: 5)
        defer { files.remove() }
        let fixture = try Fixture(conversation: files.conversation)
        defer { fixture.tearDown() }
        fixture.showMap(true)
        try await expectEventually { fixture.tab.conversationOutline.outline?.blocks.count == 5 }
        #expect(fixture.tab.conversationOutline.readCount == 1)

        fixture.window.miniaturize(nil)
        try await expectEventually { fixture.window.isMiniaturized }
        try files.append(ConversationOutlineModelTests.record(5))
        try await Task.sleep(
            for: ConversationOutlineModel.checkInterval(on: .thisMac) + ConversationOutlineModel.minimumReadInterval + .milliseconds(500))
        #expect(fixture.tab.conversationOutline.readCount == 1)

        fixture.window.deminiaturize(nil)
        try await expectEventually { fixture.tab.conversationOutline.outline?.blocks.count == 6 }
        #expect(fixture.tab.conversationOutline.readCount == 2)
    }

    @Test func turningTheMapOffReleasesTheOutline() async throws {
        let files = try TranscriptPagingFixture(count: 5)
        defer { files.remove() }
        let fixture = try Fixture(conversation: files.conversation)
        defer { fixture.tearDown() }
        fixture.showMap(true)
        try await expectEventually { fixture.tab.conversationOutline.outline?.blocks.count == 5 }

        fixture.showMap(false)

        try await expectEventually { fixture.tab.conversationOutline.outline == nil }
    }

    @Test func theTerminalViewsTakeNoMapInput() throws {
        for path in [
            "Sources/JustSessions/Views/Terminal/EmbeddedTerminalView.swift", "Sources/JustSessions/Views/Terminal/TerminalInsetView.swift",
        ] {
            let source = try RepositoryFiles.contents(of: path)
            for name in ["Outline", "ConversationMap", "showsConversationMap"] {
                #expect(!source.contains(name), "\(path) mentions \(name)")
            }
        }
    }
}
