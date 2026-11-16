import Foundation
import Observation

@MainActor
@Observable
final class TranscriptPagingModel {
    nonisolated static let maximumPageCount = 3
    /// Pages near the viewport stay past `maximumPageCount`, up to this many; see
    /// `TranscriptPagingViewport.retainedPageCount(afterLoading:pageStarts:)`.
    nonisolated static let maximumRetainedPageCount = 8
    private(set) var transcript: TranscriptContent?
    private(set) var pages: [TranscriptPage] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var restorationPosition: TranscriptReadingPosition = .bottom
    private(set) var revision = 0
    private var source: TranscriptPageSource?
    private var sourceKey: String?
    private var loadTask: Task<Void, Never>?
    private var requestRevision = 0

    var hasEarlier: Bool { pages.first?.hasEarlier == true }
    var hasLater: Bool { pages.last?.hasLater == true }

    func refresh(_ conversation: Conversation, position: TranscriptReadingPosition?) {
        let key = conversation.id + "|" + conversation.sourceFile.path
        if key != sourceKey {
            cancel()
            sourceKey = key
            source = TranscriptPageSource(
                file: conversation.sourceFile,
                provider: conversation.provider,
                sessionID: conversation.sessionID,
                isSubagentTranscript: conversation.isSubagent
            )
            pages = []
            transcript = nil
        }
        let position = position ?? .bottom
        request(position.entryIndex.map(TranscriptPageRequest.around) ?? .latest, preserving: position, refreshIndex: true)
    }

    /// Keeps `keepingPages` pages once the earlier page loads, dropping later ones.
    func earlier(
        preserving position: TranscriptReadingPosition, currentPosition: (() -> TranscriptReadingPosition?)? = nil,
        keepingPages: Int = maximumPageCount
    ) {
        guard !isLoading, let first = pages.first, first.hasEarlier else { return }
        request(.before(first.records.lowerBound), preserving: position, currentPosition: currentPosition, keepingPages: keepingPages)
    }

    /// Keeps `keepingPages` pages once the later page loads, dropping earlier ones.
    func later(
        preserving position: TranscriptReadingPosition, currentPosition: (() -> TranscriptReadingPosition?)? = nil,
        keepingPages: Int = maximumPageCount
    ) {
        guard !isLoading, let last = pages.last, last.hasLater else { return }
        request(.after(last.records.upperBound), preserving: position, currentPosition: currentPosition, keepingPages: keepingPages)
    }

    func first() { request(.first, preserving: .entry(index: 0, offset: -6)) }
    func latest() { request(.latest, preserving: .bottom) }

    func cancel() {
        requestRevision += 1
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    private func request(
        _ request: TranscriptPageRequest, preserving position: TranscriptReadingPosition, refreshIndex: Bool = false,
        currentPosition: (() -> TranscriptReadingPosition?)? = nil, keepingPages: Int = maximumPageCount
    ) {
        guard let source else { return }
        cancel()
        let requestRevision = requestRevision
        isLoading = true
        errorMessage = nil
        loadTask = Task { [weak self] in
            do {
                var replacedSource = false
                let page: TranscriptPage
                do {
                    let loaded = try await source.read(request, refreshIndex: refreshIndex)
                    if case .before = request, let previous = self?.pages.first, previous.sourceLineage != loaded.sourceLineage {
                        throw TranscriptPagingError.sourceChanged
                    }
                    if case .after = request, let previous = self?.pages.last, previous.sourceLineage != loaded.sourceLineage {
                        throw TranscriptPagingError.sourceChanged
                    }
                    page = loaded
                } catch TranscriptPagingError.sourceChanged {
                    try Task.checkCancellation()
                    // The old window's record ranges belong to another file generation. Rebuild around the reader.
                    let current = currentPosition?() ?? position
                    let retry: TranscriptPageRequest
                    switch request {
                    case .before, .after: retry = current.entryIndex.map(TranscriptPageRequest.around) ?? .latest
                    default: retry = request
                    }
                    page = try await source.read(retry, refreshIndex: true)
                    replacedSource = true
                }
                try Task.checkCancellation()
                guard let self, self.requestRevision == requestRevision else { return }
                // A reader may keep scrolling while the next page is decoded. Preserve where they are now.
                let position = currentPosition?() ?? position
                switch (request, replacedSource) {
                case (.before, false):
                    self.pages.insert(page, at: 0)
                    self.pages = Array(self.pages.prefix(keepingPages))
                case (.after, false):
                    self.pages.append(page)
                    self.pages = Array(self.pages.suffix(keepingPages))
                default: self.pages = [page]
                }
                let transcript = TranscriptPageAssembler.transcript(pages: self.pages)
                self.transcript = transcript
                if case .first = request, let first = transcript.positionIDs.first {
                    self.restorationPosition = .entry(index: first, offset: -6)
                } else {
                    self.restorationPosition = position.resolved(in: transcript)
                }
                self.revision += 1
                self.isLoading = false
                self.loadTask = nil
            } catch is CancellationError {
                // A new request owns the loading state.
            } catch {
                guard let self, self.requestRevision == requestRevision else { return }
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.loadTask = nil
            }
        }
    }
}
