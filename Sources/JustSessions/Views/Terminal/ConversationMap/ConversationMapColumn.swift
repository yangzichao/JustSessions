import SwiftUI

struct ConversationMapColumn: View, Equatable {
    let model: ConversationOutlineModel
    let conversation: Conversation?
    let provider: ConversationProvider
    let isShown: Bool
    let store: ConversationStore
    let hover: ConversationMapHover
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
