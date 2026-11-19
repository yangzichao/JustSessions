import SwiftUI

struct TerminalWorkspaceView: View {
    @ObservedObject var session: TerminalSession
    let isShown: Bool
    let isActive: Bool
    let onReconnect: (() -> Void)?
    let onCheckHost: (() -> Void)?
    var hostProblem: () -> String? = { nil }
    let onFocus: () -> Void
    let makeContextMenu: (_ linkUnderPointer: String?) -> NSMenu
    let onOpenLink: (_ link: String) -> Void
    var store: ConversationStore? = nil
    @State private var mapHover = ConversationMapHover()

    var body: some View {
        VStack(spacing: 0) {
            if session.hasExited {
                TerminalEndedBar(
                    exitCode: session.exitCode,
                    isWaitingToReconnect: session.isWaitingToReconnect,
                    endedWithErrorSoonAfterStarting: session.endedWithErrorSoonAfterStarting,
                    hostProblem: hostProblem(),
                    onCheckHost: onCheckHost,
                    onReconnect: onReconnect.map { reconnect in
                        {
                            onFocus()
                            reconnect()
                        }
                    }
                )
                ThemeDivider()
            }
            HStack(spacing: 0) {
                EmbeddedTerminalView(
                    session: session,
                    isShown: isShown,
                    isActive: isActive,
                    onFocus: onFocus,
                    makeContextMenu: makeContextMenu,
                    onOpenLink: onOpenLink
                )
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        if session.findState.isPresented {
                            TerminalFindBar(findState: session.findState)
                                .padding([.top, .horizontal], TerminalSSHFileDropNotice.marginFromTerminalEdges)
                        }
                        TerminalBookmarkNoticeCard(state: session.bookmarkNotices)
                        if let sshFileDrop = session.sshFileDrop { TerminalSSHFileDropNotice(fileDrop: sshFileDrop) }
                    }
                }
                if let provider = session.provider, let store {
                    ConversationMapColumn(
                        model: session.conversationOutline, conversation: session.conversation, provider: provider,
                        isShown: isShown, store: store, hover: mapHover, editor: session.bookmarkNotices.editor
                    )
                    .equatable()
                }
            }
            .overlay(alignment: .topTrailing) { ConversationMapHoverCard(hover: mapHover) }
        }
        .messageBookmarkEditor(session.bookmarkNotices.editor, store: store)
        .onChange(of: session.findState.closeRevision) {
            guard isActive else { return }
            session.terminalView.window?.makeFirstResponder(session.terminalView)
        }
        .onChange(of: session.findState.isFieldFocused) {
            if session.findState.isFieldFocused && !isActive { onFocus() }
        }
    }
}
