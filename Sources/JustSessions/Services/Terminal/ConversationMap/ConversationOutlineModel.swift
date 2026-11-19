import Foundation
import Observation

/// One tab's conversation-map outline and its session reader for ⌘D. Held by `TerminalSession`, so it follows the tab to
/// another window. In memory only; never published through ConversationStore; never an input of the terminal's views.
@MainActor
@Observable
final class ConversationOutlineModel {
    nonisolated static let minimumReadInterval: Duration = .seconds(2)
    nonisolated static let maximumReadInterval: Duration = .seconds(30)
    /// A read waits at least this many times as long as the last took: a 95 MiB Pi branch scan costs ≤ about 1/5 core.
    nonisolated static let readCostMultiple = 4
    nonisolated static func checkInterval(on host: SessionHost) -> Duration { host == .thisMac ? .seconds(1) : .seconds(5) }

    private(set) var outline: ConversationOutline?
    private(set) var couldNotRead = false
    /// For tests and measurements.
    @ObservationIgnored private(set) var readCount = 0
    @ObservationIgnored private var reader: ConversationOutlineReader?
    @ObservationIgnored private var sourceKey: String?
    @ObservationIgnored private var watchGeneration = 0
    /// The generation of the watch still running, if any. While it runs only a watch replaces the reader; with the map
    /// off or hidden, ⌘D keeps its reader (and index) for the next press.
    @ObservationIgnored private var runningWatch: Int?
    /// The reader a read runs for. A reader a relink installed reads at once while its predecessor's read unwinds.
    @ObservationIgnored private var readingReader: ConversationOutlineReader?
    @ObservationIgnored private var nextReadAt = ContinuousClock.now
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private let checkIntervalOverride: Duration?
    @ObservationIgnored private let minimumInterval: Duration

    init(checkInterval: Duration? = nil, minimumReadInterval: Duration = ConversationOutlineModel.minimumReadInterval) {
        checkIntervalOverride = checkInterval
        minimumInterval = minimumReadInterval
    }

    /// While the map shows this session on screen (ConversationMapView's .task): a stat every check interval, a read
    /// when it changed, throttled. Ends when cancelled, or when a newer watch (the tab's view in another window) starts.
    func watch(_ conversation: Conversation) async {
        let reader = prepare(for: conversation)
        watchGeneration += 1
        let generation = watchGeneration
        runningWatch = generation
        defer { if runningWatch == generation { runningWatch = nil } }
        let interval = checkIntervalOverride ?? Self.checkInterval(on: conversation.host)
        while !Task.isCancelled, generation == watchGeneration {
            if await reader.hasChanged() {
                let wait = nextReadAt - .now
                if wait > .zero { try? await Task.sleep(for: wait) }
                guard !Task.isCancelled, generation == watchGeneration else { return }
                await read(with: reader)
            }
            try? await Task.sleep(for: interval)
        }
    }

    /// ⌘D (TRM-74). A press queued before a relink reads the session the tab left with a reader of its own: taking the
    /// running watch's slot would hide every read it makes until the map's task restarts.
    func latestMessage(of conversation: Conversation) async throws -> TranscriptEntry? {
        if runningWatch == watchGeneration, Self.key(of: conversation) != sourceKey {
            return try await ConversationOutlineReader(conversation).latestMessage()
        }
        return try await prepare(for: conversation).latestMessage()
    }

    /// The map was turned off or the tab closed: drop the outline and the reader with its index.
    func release() {
        watchGeneration += 1
        reader = nil
        sourceKey = nil
        if outline != nil { outline = nil }
        if couldNotRead { couldNotRead = false }
    }

    private func read(with reader: ConversationOutlineReader) async {
        guard readingReader !== reader else { return }
        readingReader = reader
        defer { if readingReader === reader { readingReader = nil } }
        let started = ContinuousClock.now
        readCount += 1
        do {
            if let updated = try await reader.update(), reader === self.reader {
                revision += 1
                var stamped = updated
                stamped.revision = revision
                outline = stamped
            }
            if couldNotRead { couldNotRead = false }
        } catch is CancellationError {
            return  // the map was hidden: showing it again reads at once
        } catch {
            if outline == nil, reader === self.reader { couldNotRead = true }
        }
        // Only a finished read of the session shown spaces the next (PERF-89), not one a relink or release left behind.
        guard reader === self.reader else { return }
        nextReadAt = .now + min(Self.maximumReadInterval, max(minimumInterval, (ContinuousClock.now - started) * Self.readCostMultiple))
    }

    /// A relinked tab (/clear) starts a new outline; the key is the reader's (TranscriptPagingModel.swift:26).
    @discardableResult
    private func prepare(for conversation: Conversation) -> ConversationOutlineReader {
        let key = Self.key(of: conversation)
        if key == sourceKey, let reader { return reader }
        sourceKey = key
        let reader = ConversationOutlineReader(conversation)
        self.reader = reader
        if outline != nil { outline = nil }
        couldNotRead = false
        nextReadAt = .now
        return reader
    }

    private static func key(of conversation: Conversation) -> String { conversation.id + "|" + conversation.sourceFile.path }
}
