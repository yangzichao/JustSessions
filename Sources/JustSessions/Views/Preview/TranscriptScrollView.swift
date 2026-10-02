import SwiftUI

struct TranscriptScrollView: View {
    let conversation: Conversation
    let transcript: TranscriptContent
    @State private var visibleEntryIndex: Int?
    @State private var positionController: TranscriptScrollPositionController
    @State private var readingFontSize: CGFloat = 15
    @AppStorage(TranscriptReadingWidth.userDefaultsKey) private var readingWidth = TranscriptReadingWidth.readable
    private let initialPosition: TranscriptReadingPosition

    init(conversation: Conversation, transcript: TranscriptContent, positionStore: TranscriptReadingPositionStore) {
        self.conversation = conversation
        self.transcript = transcript
        let initialPosition = (positionStore.position(for: conversation.id) ?? .bottom).resolved(in: transcript)
        self.initialPosition = initialPosition
        _visibleEntryIndex = State(initialValue: initialPosition.entryIndex)
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
                            onFirstMessage: {
                                guard let index = displayedEntryIndices.first else { return }
                                positionController.restore(.entry(index: index, offset: -6))
                                visibleEntryIndex = index
                            },
                            onLatestMessage: {
                                positionController.restore(.bottom)
                                visibleEntryIndex = displayedEntryIndices.last
                            }
                        )
                        ThemeDivider()
                    }
                    .background(ThemePalette.contentSurface)
                }
                .environment(\.transcriptReadingFontSize, readingFontSize)
                .onChange(of: readingFontSize) { positionController.restoreRecordedPosition() }
                .onChange(of: readingWidth) { positionController.restoreRecordedPosition() }
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
                if transcript.omittedEntryCount > 0 {
                    Text("\(transcript.omittedEntryCount) earlier entries are not shown. Resume the session to see all of it.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                // Only messages participate in scroll targeting; the omitted-entry notice has no message index.
                transcriptEntries
            }
            .frame(maxWidth: readingWidth.maximumColumnWidth, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
        }
        // Short conversations start at the top; the explicit restoration still opens long ones on their latest entry.
        .defaultScrollAnchor(.top)
        .scrollPosition(id: scrollTarget, anchor: .top)
        .onDisappear { positionController.stop() }
    }

    private var transcriptEntries: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(displayedEntryIndices, id: \.self) { entryIndex in
                let entry = transcript.entries[entryIndex - transcript.omittedEntryCount]
                TranscriptEntryView(
                    entry: entry,
                    assistantName: conversation.provider.rawValue,
                    assistantTint: conversation.provider.tintColor
                )
                .background(TranscriptEntryPositionMarker(entryIndex: entryIndex, controller: positionController))
                .id(entryIndex)
            }
        }
        .scrollTargetLayout()
    }

    private var displayedEntryIndices: Range<Int> {
        transcript.omittedEntryCount..<(transcript.omittedEntryCount + transcript.entries.count)
    }

    private var scrollTarget: Binding<Int?> {
        Binding(
            get: { visibleEntryIndex },
            set: { index in
                // Estimated lazy heights must not replace the requested entry before its offset is restored.
                if !positionController.isRestoring { visibleEntryIndex = index }
            }
        )
    }

    private var messageCount: Int {
        transcript.entries.filter { entry in
            switch entry.content { case .userMessage, .assistantMessage: true; default: false }
        }.count
    }
}
