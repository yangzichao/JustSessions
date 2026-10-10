import SwiftUI

struct TranscriptScrollView: View {
    let conversation: Conversation
    let transcript: TranscriptContent
    let isActive: Bool
    let paging: TranscriptPagingModel?
    let onOpenInNewWindow: (() -> Void)?
    /// Records the reading position and restores it. Nothing else tracks where the reader is: SwiftUI's own tracking, with
    /// `.scrollPosition(id:)`, searched every entry on each scroll step for the one at the top.
    @State var positionController: TranscriptScrollPositionController
    @State var restoredPagingRevision: Int?
    @State private var readingFontSize: CGFloat = 15
    @State var searchState: TranscriptSearchState
    @State var searchIndex: TranscriptSearchIndex?
    @State var indexedTranscript: TranscriptContent?
    @State var indexedQuery = ""
    @AppStorage(TranscriptReadingWidth.userDefaultsKey) private var readingWidth = TranscriptReadingWidth.readable
    private let initialPosition: TranscriptReadingPosition

    init(
        conversation: Conversation, transcript: TranscriptContent, positionStore: TranscriptReadingPositionStore,
        isActive: Bool = true, searchState: TranscriptSearchState = TranscriptSearchState(), paging: TranscriptPagingModel? = nil,
        onOpenInNewWindow: (() -> Void)? = nil
    ) {
        self.conversation = conversation
        self.transcript = transcript
        self.isActive = isActive
        self.paging = paging
        self.onOpenInNewWindow = onOpenInNewWindow
        _restoredPagingRevision = State(initialValue: paging?.revision)
        _searchState = State(initialValue: searchState)
        let initialPosition = (positionStore.position(for: conversation.id) ?? .bottom).resolved(in: transcript)
        self.initialPosition = initialPosition
        _positionController = State(initialValue: TranscriptScrollPositionController(
            conversationID: conversation.id,
            positionStore: positionStore,
            initialPosition: initialPosition
        ))
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            transcriptScrollView
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        TranscriptReadingToolbar(
                            fontSize: $readingFontSize,
                            readingWidth: $readingWidth,
                            messageCount: messageCount,
                            onFirstMessage: showFirstMessage,
                            onLatestMessage: showLatestMessage,
                            onFind: searchState.show,
                            onOpenInNewWindow: onOpenInNewWindow
                        )
                        .disabled(!isActive)
                        if searchState.isPresented {
                            ThemeDivider()
                            TranscriptSearchBar(searchState: searchState, hasOmittedEntries: transcript.omittedEntryCount > 0 || paging?.hasEarlier == true || paging?.hasLater == true)
                        }
                        ThemeDivider()
                    }
                    .background(ThemePalette.contentSurface)
                }
                .environment(\.transcriptReadingFontSize, readingFontSize)
                .environment(\.transcriptSearchContext, TranscriptSearchContext(
                    query: searchState.isPresented ? searchState.query : "",
                    selectedMatch: searchState.isSearching ? nil : searchState.selectedMatch,
                    navigationRevision: searchState.navigationRevision,
                    positionController: positionController
                ))
                .background(TranscriptSearchKeyboardShortcuts(searchState: searchState, isActive: isActive))
                .task(id: SearchRequest(query: searchState.query, isPresented: searchState.isPresented && isActive, transcript: transcript)) {
                    await updateSearch()
                }
                .onChange(of: searchState.navigationRevision) {
                    guard let match = searchState.selectedMatch else { return }
                    positionController.restore(.entry(index: match.entryIndex, offset: -6))
                    scrollProxy.scrollTo(match.entryIndex, anchor: .top)
                }
                .onChange(of: isActive) {
                    if !isActive { searchState.close() } else { prefetchIfNeeded() }
                }
                .onChange(of: searchState.isPresented) { positionController.restoreRecordedPosition() }
                .onChange(of: readingFontSize) { positionController.restoreRecordedPosition() }
                .onChange(of: readingWidth) { positionController.restoreRecordedPosition() }
                .onChange(of: paging?.revision) { restorePagedPosition(using: scrollProxy) }
                .onReceive(positionController.viewportUpdates) { prefetchIfNeeded(in: $0) }
                .onAppear { positionController.tracksTranscriptBottom = paging?.hasLater != true }
                .onReceive(positionController.entrySeekingRequests) { index in
                    scrollProxy.scrollTo(index, anchor: .top)
                }
                .task {
                    if let index = initialPosition.entryIndex { scrollProxy.scrollTo(index, anchor: .top) }
                }
        }
    }

    private var transcriptScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let paging, paging.hasEarlier {
                    TranscriptPageBoundary(isEarlier: true, isLoading: paging.isLoading, action: loadEarlierPage)
                        .disabled(!isActive)
                } else if transcript.omittedEntryCount > 0 {
                    Text("\(transcript.omittedEntryCount) earlier entries are not shown. Resume the session to see all of it.")
                        .font(.caption)
                        .foregroundStyle(ThemePalette.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                TranscriptEntriesStack(transcript: transcript, provider: conversation.provider, positionController: positionController)
                    .equatable()
                if let paging, paging.hasLater {
                    TranscriptPageBoundary(isEarlier: false, isLoading: paging.isLoading, action: loadLaterPage)
                        .disabled(!isActive)
                }
                if let message = paging?.errorMessage {
                    Text(verbatim: message).font(.caption).foregroundStyle(ThemePalette.secondaryText).padding(12)
                }
            }
            .frame(maxWidth: readingWidth.maximumColumnWidth, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
        }
        // Short conversations start at the top; the explicit restoration still opens long ones on their latest entry.
        .defaultScrollAnchor(.top)
        .onDisappear { positionController.stop() }
    }

    var displayedEntryIndices: [Int] { transcript.positionIDs }

    private var messageCount: Int {
        transcript.entries.filter { entry in
            switch entry.content { case .userMessage, .assistantMessage: true; default: false }
        }.count
    }
}
