import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// The tab bar stays in sight whatever shows below it. The window's content runs up under its hidden title bar, whose
/// safe area is taller than the bar, and a background below the bar that extends through that safe area, as the
/// preview's and an ended tab's bar do, used to paint over it.
@MainActor
struct TabBarVisibilityTests {
    /// The detail area in a window like the app's, with its content under a hidden title bar.
    @MainActor
    private final class Fixture {
        let store: ConversationStore
        let settings: IsolatedUserDefaults
        let transcript: TranscriptPagingFixture
        let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        private let window: NSWindow

        init() throws {
            _ = NSApplication.shared
            settings = try IsolatedUserDefaults()
            store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
            transcript = try TranscriptPagingFixture(count: 20)
            store.replaceConversations(on: .thisMac, with: [transcript.conversation])
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 500),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = hostingView
        }

        func openTab(running executablePath: String, on host: SessionHost = .thisMac) -> TerminalSession {
            let tab = TerminalSession(
                engine: .swiftTerm,
                conversation: nil, provider: nil, projectPath: "/tmp", action: nil, displayTitle: "Tab",
                command: NativeCLICommand(executablePath: executablePath, arguments: [], workingDirectory: "/tmp", environment: []),
                host: host
            )
            store.openTerminal(tab)
            return tab
        }

        /// Shows the detail area with `selection`, then returns the color drawn in the bar's empty end, past every tab.
        func barColor(selecting selection: SessionMultiSelection) async throws -> NSColor {
            hostingView.rootView = AnyView(
                WorkspaceDetailView(
                    store: store, sessionSelection: selection, isSidebarHidden: false,
                    onRename: { _ in }, onCloseTerminal: { _ in }, onDelete: { _ in }
                )
                .defaultAppStorage(settings.userDefaults)
            )
            for _ in 0..<12 {
                hostingView.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(25))
            }
            let bitmap = try #require(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
            let scale = CGFloat(bitmap.pixelsWide) / hostingView.bounds.width
            // Halfway down the bar, near the window's trailing edge.
            return try #require(bitmap.colorAt(x: Int((hostingView.bounds.width - 40) * scale), y: Int(14 * scale)))
        }

        func close() {
            store.closeAllTerminals()
            hostingView.rootView = AnyView(EmptyView())
            window.close()
            settings.removeSuite()
            transcript.remove()
        }
    }

    @Test func theBarStaysInSightWhileASessionWithoutATabShows() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let tab = fixture.openTab(running: "/bin/cat")
        fixture.store.selectTerminal(tab.id)
        let barBehindATerminal = try await fixture.barColor(selecting: SessionMultiSelection())

        var selection = SessionMultiSelection()
        selection.selectOnly(fixture.transcript.conversation.id)
        fixture.store.selectTerminal(nil)
        let barBehindThePreview = try await fixture.barColor(selecting: selection)

        #expect(barBehindThePreview == barBehindATerminal)
    }

    /// On this Mac, the ended bar says how the CLI exited; on an SSH host, whose connection dropped, it offers Reconnect.
    @Test(arguments: [SessionHost.thisMac, .ssh("devbox")])
    func theBarStaysInSightWhileATabWhoseCLIEndedShows(on host: SessionHost) async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let runningTab = fixture.openTab(running: "/bin/cat")
        fixture.store.selectTerminal(runningTab.id)
        let barBehindATerminal = try await fixture.barColor(selecting: SessionMultiSelection())

        let endedTab = fixture.openTab(running: "/usr/bin/true", on: host)
        fixture.store.selectTerminal(endedTab.id)
        _ = try await fixture.barColor(selecting: SessionMultiSelection())
        try await expectEventually { endedTab.hasExited }
        let barBehindTheEndedBar = try await fixture.barColor(selecting: SessionMultiSelection())

        #expect(barBehindTheEndedBar == barBehindATerminal)
    }
}
