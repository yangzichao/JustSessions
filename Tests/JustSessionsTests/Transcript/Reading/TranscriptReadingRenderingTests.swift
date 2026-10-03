import AppKit
import SwiftUI
import Testing
@testable import JustSessions

@MainActor
struct TranscriptReadingRenderingTests {
    @Test func readingLayoutsRenderAtWideAndNarrowWidths() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let conversation = TranscriptScrollViewFixture.conversation("A calmer way to read a session before resuming")
        let transcript = sampleTranscript
        for width in [820.0, 400.0] {
            let positions = TranscriptReadingPositionStore()
            positions.record(.entry(index: 0, offset: 0), for: conversation.id)
            let content = VStack(spacing: 0) {
                SessionPreviewHeader(store: store, conversation: conversation, onRename: {}, onDelete: {})
                ThemeDivider()
                TranscriptScrollView(conversation: conversation, transcript: transcript, positionStore: positions)
            }
            .background(ThemePalette.contentSurface)
            .defaultAppStorage(settings.userDefaults)
            for scheme in [ColorScheme.light, .dark] {
                let fixture = ThemeSurfaceRenderingFixture(content: AnyView(content), size: CGSize(width: width, height: 920), colorScheme: scheme)
                defer { fixture.close() }
                let bitmap = try await fixture.capture(named: "reading-preview-\(Int(width))-\(scheme)")
                #expect(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0)
            }
        }
    }

    @Test func independentReaderLoadsTheRealTranscriptWithoutOpeningATerminal() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceFile = directory.appendingPathComponent("reader.jsonl")
        let record: [String: Any] = ["type": "assistant", "message": ["content": markdown]]
        try JSONSerialization.data(withJSONObject: record).write(to: sourceFile)
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let conversation = Conversation(provider: .claude, sessionID: "reading-window-fixture", projectPath: directory.path,
                                        suggestedTitle: "Read before you resume", updatedAt: .now, sourceFile: sourceFile)
        let content = SessionReadingView(store: store, conversation: conversation, readingPositionStore: TranscriptReadingPositionStore())
            .defaultAppStorage(settings.userDefaults)
        let fixture = ThemeSurfaceRenderingFixture(content: AnyView(content), size: CGSize(width: 760, height: 900), colorScheme: .light)
        defer { fixture.close() }
        let bitmap = try await fixture.capture(named: "independent-session-reader")
        #expect(bitmap.pixelsWide > 0)
        #expect(store.terminalSessions.isEmpty)
    }

    private var sampleTranscript: TranscriptContent {
        TranscriptContent(entries: [
            .init(id: 0, content: .userMessage("帮我整理这次会话的改动，先阅读，再决定是否继续。"), timestamp: nil, startsTurn: true),
            .init(id: 1, content: .toolCalls(["Read Sources/Preview.swift", "swift build"]), timestamp: nil, startsTurn: true),
            .init(id: 2, content: .assistantMessage(markdown), timestamp: nil, startsTurn: false),
        ], omittedEntryCount: 0)
    }

    private var markdown: String {
        """
        ## Read at your own pace

        Clear paragraphs, **important details**, and `inline code` keep the conversation easy to scan.

        - Browse without starting the CLI.
        - Keep your place when switching sessions.

        ```swift
        let session = sessions.selected
        reader.open(session)
        ```

        | Action | Result |
        | --- | --- |
        | Read | A separate reading window |
        | Resume | Continue in the native CLI |

        > Tool calls stay folded until you need them.
        """
    }
}
