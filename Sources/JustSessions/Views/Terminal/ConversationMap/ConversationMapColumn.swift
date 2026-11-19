import SwiftUI

/// The conversation map's column beside a CLI tab's terminal (TAB-09): no width while the map is off, a fixed width while
/// it is on, whatever the tab shows. Equatable on its inputs, so a tab's activity or title change, which re-runs
/// TerminalWorkspaceView, leaves it alone; the toggle (its own @AppStorage) still updates it. A hidden tab's column
/// draws only its background: no Canvas, no bookmarks read, no file checks (PERF-89).
struct ConversationMapColumn: View, Equatable {
    let model: ConversationOutlineModel
    let conversation: Conversation?
    let provider: ConversationProvider
    let isShown: Bool
    let store: ConversationStore
    let hover: ConversationMapHover
    /// The tab's Edit Bookmark… sheet, which a bookmark letter's right-click menu opens (TAB-10).
    var editor: MessageBookmarkEditorRequests? = nil
    @AppStorage(ConversationMapVisibility.userDefaultsKey) private var showsMap = ConversationMapVisibility.isShownByDefault
    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    nonisolated static func == (first: Self, second: Self) -> Bool {
        first.model === second.model && first.conversation == second.conversation && first.provider == second.provider
            && first.isShown == second.isShown && first.store === second.store && first.hover === second.hover
            && first.editor === second.editor
    }

    var body: some View {
        ZStack {
            if showsMap {
                terminalPalette.backgroundColor
                if isShown {
                    ConversationMapView(
                        model: model, conversation: conversation, provider: provider, store: store, hover: hover,
                        editor: editor)
                }
            }
        }
        .frame(width: showsMap ? ConversationMapMetrics.columnWidth : 0)
        .frame(maxHeight: .infinity)
        // It sits on the terminal's background, which can be dark in a light window, as the split's mini toolbar does.
        .environment(\.colorScheme, terminalPalette.colorScheme)
        .onChange(of: showsMap) {
            if !showsMap {
                model.release()
                hover.hide()
            }
        }
        .onChange(of: isShown) {
            if !isShown { hover.hide() }
        }
    }
}
