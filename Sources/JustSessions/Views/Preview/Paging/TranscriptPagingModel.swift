import Foundation
import Observation

@MainActor
@Observable
final class TranscriptPagingModel {
    static let maximumPageCount = 3
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
            source = TranscriptPageSource(file: conversation.sourceFile, provider: conversation.provider)
            pages = []
            transcript = nil
        }
        let position = position ?? .bottom
        request(position.entryIndex.map(TranscriptPageRequest.around) ?? .latest, preserving: position, refreshIndex: true)
    }

    func earlier(preserving position: TranscriptReadingPosition) {
        guard !isLoading, let first = pages.first, first.hasEarlier else { return }
        request(.before(first.records.lowerBound), preserving: position)
    }

    func later(preserving position: TranscriptReadingPosition) {
        guard !isLoading, let last = pages.last, last.hasLater else { return }
        request(.after(last.records.upperBound), preserving: position)
    }

    func first() { request(.first, preserving: .entry(index: 0, offset: -6)) }
    func latest() { request(.latest, preserving: .bottom) }

    func cancel() {
        requestRevision += 1
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    private func request(_ request: TranscriptPageRequest, preserving position: TranscriptReadingPosition, refreshIndex: Bool = false) {
        guard let source else { return }
        cancel()
        let requestRevision = requestRevision
        isLoading = true
        errorMessage = nil
        loadTask = Task { [weak self] in
            do {
                let page = try await source.read(request, refreshIndex: refreshIndex)
                try Task.checkCancellation()
                guard let self, self.requestRevision == requestRevision else { return }
                switch request {
                case .before:
                    self.pages.insert(page, at: 0)
                    self.pages = Array(self.pages.prefix(Self.maximumPageCount))
                case .after:
                    self.pages.append(page)
                    self.pages = Array(self.pages.suffix(Self.maximumPageCount))
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
