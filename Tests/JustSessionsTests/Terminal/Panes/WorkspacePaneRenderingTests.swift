import AppKit
import SwiftUI
import Testing
@testable import JustSessions

@MainActor
struct WorkspacePaneRenderingTests {
    /// Without splits, the pane path must draw exactly what the previous single-pane detail view drew.
    @Test func unsplitDetailRendersPixelIdenticalToTheLegacyStructure() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let size = CGSize(width: 900, height: 700)

        let current = WorkspaceDetailView(
            store: store, sessionSelection: SessionMultiSelection(),
            onRename: { _ in }, onCloseTerminal: { _ in }, onDelete: { _ in }
        )
        let legacy = LegacyDetailStructure(store: store)

        var pngs: [Data] = []
        for view in [AnyView(current), AnyView(legacy)] {
            let fixture = ThemeSurfaceRenderingFixture(
                content: AnyView(view.background(ThemePalette.contentSurface)), size: size, colorScheme: .light
            )
            defer { fixture.close() }
            let bitmap = try await fixture.capture(named: "unsplit-equivalence")
            pngs.append(try #require(bitmap.representation(using: .png, properties: [:])))
        }

        #expect(pngs[0] == pngs[1])
    }

    @Test func nestedThreePaneLayoutRendersInLightAndDark() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let tabA = Self.terminal(title: "blender · pi", projectPath: "/work/blender")
        let tabB = Self.terminal(title: "api · claude", projectPath: "/work/api")
        store.openTerminal(tabA)
        store.openTerminal(tabB)
        defer { store.closeAllTerminals() }
        store.dockPane(.terminal(tabA.id), on: .trailing, of: .selection)
        store.dockPane(.terminal(tabB.id), on: .bottom, of: .terminal(tabA.id))
        #expect(store.paneLayout.panes == [.selection, .terminal(tabA.id), .terminal(tabB.id)])

        let view = WorkspaceDetailView(
            store: store, sessionSelection: SessionMultiSelection(),
            onRename: { _ in }, onCloseTerminal: { _ in }, onDelete: { _ in }
        )
        for scheme in [ColorScheme.light, .dark] {
            let fixture = ThemeSurfaceRenderingFixture(
                content: AnyView(view.background(ThemePalette.contentSurface)),
                size: CGSize(width: 1_100, height: 760),
                colorScheme: scheme
            )
            defer { fixture.close() }
            let bitmap = try await fixture.capture(named: "workspace-panes-nested-\(scheme == .light ? "light" : "dark")")
            #expect(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0)
        }
    }

    /// A read-only preview docked beside the selected tab's terminal, fed by a real session file.
    @Test func terminalAndPreviewSplitRendersTheTranscript() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceFile = directory.appendingPathComponent("preview-pane.jsonl")
        let lines = [
            ["type": "user", "message": ["role": "user", "content": "Render the scene and show me"]] as [String: Any],
            ["type": "assistant", "message": ["role": "assistant", "content": "Rendered. The penguin now has a fish cannon."]],
        ]
        let data = try lines.map { try JSONSerialization.data(withJSONObject: $0) }.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n")
        try Data(data.utf8).write(to: sourceFile)
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let conversation = Conversation(
            provider: .claude, sessionID: "preview-pane-fixture", projectPath: directory.path,
            suggestedTitle: "Fish cannon review", updatedAt: .now, sourceFile: sourceFile
        )
        store.replaceConversations(on: .thisMac, with: [conversation])
        let tab = Self.terminal(title: "blender · pi", projectPath: directory.path)
        store.openTerminal(tab)
        defer { store.closeAllTerminals() }
        store.dockPane(.preview(conversation.id), on: .trailing, of: .selection)
        #expect(store.paneLayout.panes == [.selection, .preview(conversation.id)])

        let view = WorkspaceDetailView(
            store: store, sessionSelection: SessionMultiSelection(),
            onRename: { _ in }, onCloseTerminal: { _ in }, onDelete: { _ in }
        )
        let fixture = ThemeSurfaceRenderingFixture(
            content: AnyView(view.background(ThemePalette.contentSurface)),
            size: CGSize(width: 1_200, height: 760),
            colorScheme: .light
        )
        defer { fixture.close() }
        let bitmap = try await fixture.capture(named: "workspace-panes-terminal-preview")
        #expect(bitmap.pixelsWide > 0)
    }

    /// The drop-zone highlight a dragged tab sees, drawn over the pane half it would take.
    @Test func dropZoneHighlightIsVisibleOverAPane() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let tab = Self.terminal(title: "blender · pi", projectPath: "/work/blender")
        store.openTerminal(tab)
        defer { store.closeAllTerminals() }
        store.dockPane(.terminal(tab.id), on: .trailing, of: .selection)

        let size = CGSize(width: 1_000, height: 700)
        let resolution = WorkspacePaneGeometry.resolve(store.paneLayout, in: CGRect(origin: .zero, size: size))
        let paneRect = try #require(resolution.paneRects[.terminal(tab.id)])
        let highlight = WorkspacePaneDropZone.edge(.bottom).highlightRect(in: paneRect)
        let view = ZStack(alignment: .topLeading) {
            WorkspaceDetailView(
                store: store, sessionSelection: SessionMultiSelection(),
                onRename: { _ in }, onCloseTerminal: { _ in }, onDelete: { _ in }
            )
            WorkspacePaneDropHighlight()
                .frame(width: highlight.width, height: highlight.height)
                .position(x: highlight.midX, y: highlight.midY + 32) // Below the tab bar the detail view adds.
        }

        let fixture = ThemeSurfaceRenderingFixture(
            content: AnyView(view.background(ThemePalette.contentSurface)), size: size, colorScheme: .dark
        )
        defer { fixture.close() }
        let bitmap = try await fixture.capture(named: "workspace-panes-drop-highlight")
        #expect(bitmap.pixelsWide > 0)
    }

    private static func terminal(title: String, projectPath: String) -> TerminalSession {
        TerminalSession(
            conversation: nil,
            provider: .pi,
            projectPath: projectPath,
            action: .new,
            displayTitle: title,
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
    }
}

/// The detail view's structure before panes existed, kept verbatim for the equivalence capture.
private struct LegacyDetailStructure: View {
    @ObservedObject var store: ConversationStore

    var body: some View {
        VStack(spacing: 0) {
            if !store.terminalSessions.isEmpty {
                WorkspaceTabBar(store: store, onRenameConversation: { _ in }, onCloseTerminal: { _ in })
                ThemeDivider()
            }
            ZStack {
                SessionPreviewPane(
                    store: store,
                    sessionSelection: SessionMultiSelection(),
                    onRename: { _ in },
                    onDelete: { _ in }
                )
                .opacity(store.selectedTerminalID == nil ? 1 : 0)
            }
        }
        .background(ThemePalette.contentSurface)
    }
}
