import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// A session whose project folder was moved or renamed after it ran: its header says where the folder was, and stops
/// once the folder is back and the app comes to the front again.
@MainActor
struct MissingProjectFolderNoteTests {
    @Test func headerNotesTheMissingFolderUntilItIsBackAndTheAppIsActiveAgain() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let parentFolder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parentFolder) }
        let movedFolder = parentFolder.appendingPathComponent("moved-away")

        for width in [820.0, 400.0] {
            let sessionHeader = HostedSessionHeader(store: store, conversation: conversation(in: movedFolder), width: width)
            defer { sessionHeader.close() }
            let heightWithNote = try await sessionHeader.settledHeight()
            #expect(!store.canLaunch(conversation(in: movedFolder), action: .resume))

            try FileManager.default.createDirectory(at: movedFolder, withIntermediateDirectories: false)
            let heightBeforeTheAppIsActiveAgain = try await sessionHeader.settledHeight()
            #expect(heightBeforeTheAppIsActiveAgain == heightWithNote)
            NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: NSApp)
            let heightOnceTheAppIsActiveAgain = try await sessionHeader.settledHeight()
            // The note is a line of callout text or two, below the title and actions.
            #expect(heightWithNote - heightOnceTheAppIsActiveAgain >= 20)
            #expect(store.canLaunch(conversation(in: movedFolder), action: .resume))
            try FileManager.default.removeItem(at: movedFolder)
        }
    }

    @Test func noteRendersInLightAndDarkAtWideAndNarrowWidths() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let missingFolder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("code/renamed-before-resume-\(UUID().uuidString)")
        let header = SessionPreviewHeader(store: store, conversation: conversation(in: missingFolder), onRename: {}, onDelete: {})
            .background(ThemePalette.contentSurface)
        for width in [820.0, 400.0] {
            for scheme in [ColorScheme.light, .dark] {
                let fixture = ThemeSurfaceRenderingFixture(content: AnyView(header), size: CGSize(width: width, height: 220), colorScheme: scheme)
                defer { fixture.close() }
                let bitmap = try await fixture.capture(named: "missing-project-folder-\(Int(width))-\(scheme)")
                #expect(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0)
            }
        }
    }

    private func conversation(in folder: URL) -> Conversation {
        Conversation(
            provider: .claude,
            sessionID: "missing-folder-\(folder.lastPathComponent)",
            projectPath: folder.path,
            suggestedTitle: "Pick up the refactor",
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "/tmp/missing-folder.jsonl")
        )
    }
}

/// A session header in a window of a fixed width, so its height shows whether the note is there.
@MainActor
private final class HostedSessionHeader {
    private let hostingView: NSHostingView<AnyView>
    private let window: NSWindow

    init(store: ConversationStore, conversation: Conversation, width: CGFloat) {
        _ = NSApplication.shared
        let header = SessionPreviewHeader(store: store, conversation: conversation, onRename: {}, onDelete: {})
            .frame(width: width)
        hostingView = NSHostingView(rootView: AnyView(header))
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: width, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
    }

    /// The header's height once its folder check and layout have run.
    func settledHeight() async throws -> CGFloat {
        for _ in 0..<4 {
            hostingView.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
        return hostingView.fittingSize.height
    }

    func close() {
        hostingView.rootView = AnyView(EmptyView())
        window.close()
    }
}
