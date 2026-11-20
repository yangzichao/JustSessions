import SwiftUI

struct TranscriptScrollView: View {
    let conversation: Conversation
    let transcript: TranscriptContent
    let isActive: Bool
    let paging: TranscriptPagingModel?
    let onOpenInNewWindow: (() -> Void)?
    /// SwiftUI's own tracking, with `.scrollPosition(id:)`, searched every entry on each scroll step for the one at
    /// the top.
    @State var positionController: TranscriptScrollPositionController
    @State var restoredPagingRevision: Int?
    @AppStorage(TranscriptReadingTextSize.userDefaultsKey) private var readingFontSize = TranscriptReadingTextSize.defaultSize
    @State var searchState: TranscriptSearchState
    let store: ConversationStore?
    @State var bookmarkState: TranscriptBookmarkState
    let readingRequests: SessionReadingRequests?
    @State var searchIndex: TranscriptSearchIndex?
    @State var indexedTranscript: TranscriptContent?
    @State var indexedQuery = ""
    @AppStorage(TranscriptReadingWidth.userDefaultsKey) private var readingWidth = TranscriptReadingWidth.readable
    @State var textSelection = TranscriptTextSelectionCoordinator()
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme
    private let initialPosition: TranscriptReadingPosition

    init(
        conversation: Conversation, transcript: TranscriptContent, positionStore: TranscriptReadingPositionStore,
        isActive: Bool = true, searchState: TranscriptSearchState = TranscriptSearchState(), paging: TranscriptPagingModel? = nil,
        onOpenInNewWindow: (() -> Void)? = nil, store: ConversationStore? = nil,
        bookmarkState: TranscriptBookmarkState = TranscriptBookmarkState(), readingRequests: SessionReadingRequests? = nil
    ) {
        self.conversation = conversation
        self.transcript = transcript
        self.isActive = isActive
        self.paging = paging
        self.onOpenInNewWindow = onOpenInNewWindow
        self.store = store
        self.readingRequests = readingRequests
        _restoredPagingRevision = State(initialValue: paging?.revision)
        _searchState = State(initialValue: searchState)
        _bookmarkState = State(initialValue: bookmarkState)
        let initialPosition = (positionStore.position(for: conversation.id) ?? .bottom).resolved(in: transcript)
        self.initialPosition = initialPosition
        _positionController = State(
            initialValue: TranscriptScrollPositionController(
                conversationID: conversation.id,
                positionStore: positionStore,
                initialPosition: initialPosition
            ))
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            transcriptScrollView
                .transcriptBookmarkHoverCard(bookmarkState.hover)
                .overlay(alignment: .bottom) { TranscriptBookmarkNoticeCard(state: bookmarkState, onRemoveBookmark: removeBookmark) }
                .messageBookmarkEditor(bookmarkState.editor, store: store)
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        TranscriptReadingToolbar(
                            fontSize: $readingFontSize,
                            readingWidth: $readingWidth,
                            messageCount: messageCount,
                            onFirstMessage: showFirstMessage,
                            onLatestMessage: showLatestMessage,
                            onFind: searchState.show,
                            onOpenInNewWindow: onOpenInNewWindow,
                            bookmarkMenu: bookmarkMenu
                        )
                        .disabled(!isActive)
                        if searchState.isPresented {
                            ThemeDivider()
                            TranscriptSearchBar(
                                searchState: searchState,
                                hasOmittedEntries: transcript.omittedEntryCount > 0 || paging?.hasEarlier == true
                                    || paging?.hasLater == true)
                        }
                        ThemeDivider()
                    }
                    .background(ThemePalette.contentSurface)
                }
                .environment(\.transcriptReadingFontSize, TranscriptReadingTextSize.clamped(readingFontSize))
                .environment(\.transcriptTextColors, TranscriptTextColors(theme: appTheme, isDark: colorScheme == .dark))
                .environment(\.transcriptTextSelection, textSelection)
                .environment(
                    \.transcriptSearchContext,
                    TranscriptSearchContext(
                        query: searchState.isPresented ? searchState.query : "",
                        selectedMatch: searchState.isSearching ? nil : searchState.selectedMatch,
                        navigationRevision: searchState.navigationRevision,
                        positionController: positionController
                    )
                )
                .environment(\.transcriptBookmarkLetters, TranscriptBookmarkLetters(bookmarks))
                .background(TranscriptSearchKeyboardShortcuts(searchState: searchState, isActive: isActive))
                .background(TranscriptBookmarkTargetReporter(target: bookmarkCommandTarget, isActive: isActive))
                .task(id: SearchRequest(query: searchState.query, isPresented: searchState.isPresented && isActive, transcript: transcript))
            {
                await updateSearch()
            }
                .onChange(of: searchState.navigationRevision) {
                    guard let match = searchState.selectedMatch else { return }
                    positionController.clearSeekTarget()
                    positionController.restore(.startOfEntry(match.entryIndex))
                    scrollProxy.scrollTo(match.entryIndex, anchor: .top)
                }
                .onChange(of: isActive) {
                    if !isActive { searchState.close() } else { prefetchIfNeeded() }
                    updateBookmarkTarget()
                }
                .onChange(of: searchState.isPresented) { positionController.restoreRecordedPosition() }
                .onChange(of: readingFontSize) { positionController.restoreRecordedPosition() }
                .onChange(of: readingWidth) { positionController.restoreRecordedPosition() }
                .onChange(of: paging?.revision) {
                    restorePagedPosition(using: scrollProxy)
                    settleBookmarkJump()
                    settleEntryJump()
                }
                .onChange(of: readingRequests?.navigationRevision ?? 0, initial: true) { takeReadingNavigation() }
                .onReceive(positionController.viewportUpdates) { prefetchIfNeeded(in: $0) }
                .onReceive(positionController.readingUpdates) { updateBookmarkTarget() }
                .onReceive(textSelection.trackingEnded) { prefetchIfNeeded() }
                .onAppear {
                    positionController.tracksTranscriptBottom = paging?.hasLater != true
                    if let entryID = bookmarkState.takeCarriedSeekTarget() { positionController.setSeekTarget(entryID) }
                }
                .onReceive(positionController.entrySeekingRequests) { index in
                    scrollProxy.scrollTo(index, anchor: .top)
                }
                .task {
                    if let index = initialPosition.entryIndex { scrollProxy.scrollTo(index, anchor: .top) }
                }
        }
    }

    private var transcriptScrollView: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let paging, paging.hasEarlier {
                        TranscriptPageBoundary(isEarlier: true, isLoading: paging.isLoading, action: loadEarlierPage)
                            .disabled(!isActive)
                    } else if transcript.omittedEntryCount > 0 {
                        Text("\(transcript.omittedEntryCount) earlier entries are not shown. Resume the session to see all of it.")
                            .font(ThemeFont.caption)
                            .foregroundStyle(ThemePalette.tertiaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 8)
                    }
                    TranscriptEntriesStack(transcript: transcript, provider: conversation.provider, positionController: positionController)
                        .equatable()
                        .overlay(alignment: .topLeading) {
                            if bookmarksAreEnabled {
                                TranscriptBookmarkTargetMarks(target: bookmarkState.target)
                                    .frame(width: TranscriptColumnLayout.gutterWidth)
                                    .offset(x: -TranscriptColumnLayout.gutterWidth)
                                    .accessibilityHidden(true)
                            }
                        }
                    if let paging, paging.hasLater {
                        TranscriptPageBoundary(isEarlier: false, isLoading: paging.isLoading, action: loadLaterPage)
                            .disabled(!isActive)
                    }
                    if let message = paging?.errorMessage {
                        Text(verbatim: message).font(ThemeFont.caption).foregroundStyle(ThemePalette.secondaryText).padding(12)
                    }
                }
                .frame(width: columnWidth(in: viewport.size.width), alignment: .leading)
                .environment(\.transcriptColumnWidth, columnWidth(in: viewport.size.width))
                .padding(.horizontal, TranscriptColumnLayout.gutterWidth)
                .padding(.top, TranscriptColumnLayout.topPadding)
                .padding(.bottom, 36)
                .frame(width: viewport.size.width)
            }
            .defaultScrollAnchor(.top)
            .onDisappear { positionController.stop() }
        }
    }

    private func columnWidth(in viewportWidth: CGFloat) -> CGFloat {
        min(readingWidth.maximumColumnWidth, max(0, viewportWidth - 2 * TranscriptColumnLayout.gutterWidth))
    }

    var displayedEntryIndices: [Int] { transcript.positionIDs }

    private var messageCount: Int {
        transcript.entries.filter { entry in
            switch entry.content {
            case .userMessage, .assistantMessage: true
            default: false
            }
        }.count
    }
}
