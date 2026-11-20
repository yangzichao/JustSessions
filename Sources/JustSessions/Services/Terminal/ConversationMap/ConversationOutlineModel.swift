import Foundation
import Observation

@MainActor
@Observable
final class ConversationOutlineModel {
    nonisolated static let minimumReadInterval: Duration = .seconds(2)
    nonisolated static let maximumReadInterval: Duration = .seconds(30)
    nonisolated static let readCostMultiple = 4
    nonisolated static func checkInterval(on host: SessionHost) -> Duration { host == .thisMac ? .seconds(1) : .seconds(5) }

    private(set) var outline: ConversationOutline?
    private(set) var couldNotRead = false
    @ObservationIgnored private(set) var readCount = 0
    @ObservationIgnored private var reader: ConversationOutlineReader?
    @ObservationIgnored private var sourceKey: String?
    @ObservationIgnored private var watchGeneration = 0
    @ObservationIgnored private var runningWatch: Int?
    @ObservationIgnored private var readingReader: ConversationOutlineReader?
    @ObservationIgnored private var nextReadAt = ContinuousClock.now
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private let checkIntervalOverride: Duration?
    @ObservationIgnored private let minimumInterval: Duration

    init(checkInterval: Duration? = nil, minimumReadInterval: Duration = ConversationOutlineModel.minimumReadInterval) {
        checkIntervalOverride = checkInterval
        minimumInterval = minimumReadInterval
    }

    func watch(_ conversation: Conversation) async {
        let reader = prepare(for: conversation)
        let generation = startNewestWatch()
        defer { if runningWatch == generation { runningWatch = nil } }
        let interval = checkIntervalOverride ?? Self.checkInterval(on: conversation.host)
        while !Task.isCancelled, isNewestWatch(generation) {
            if await reader.hasChanged() {
                let wait = nextReadAt - .now
                if wait > .zero { try? await Task.sleep(for: wait) }
                guard !Task.isCancelled, isNewestWatch(generation) else { return }
                await read(with: reader)
            }
            try? await Task.sleep(for: interval)
        }
    }

    func latestMessage(of conversation: Conversation) async throws -> BookmarkableMessage? {
        if isNewestWatchRunning, Self.key(of: conversation) != sourceKey {
            return try await ConversationOutlineReader(conversation).latestMessage()
        }
        return try await prepare(for: conversation).latestMessage()
    }

    func release() {
        endEveryWatch()
        reader = nil
        sourceKey = nil
        if outline != nil { outline = nil }
        if couldNotRead { couldNotRead = false }
    }

    private func startNewestWatch() -> Int {
        watchGeneration += 1
        runningWatch = watchGeneration
        return watchGeneration
    }

    private func isNewestWatch(_ generation: Int) -> Bool { generation == watchGeneration }

    private var isNewestWatchRunning: Bool { runningWatch == watchGeneration }

    private func endEveryWatch() { watchGeneration += 1 }

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
            return
        } catch {
            if outline == nil, reader === self.reader { couldNotRead = true }
        }
        guard reader === self.reader else { return }
        nextReadAt = .now + min(Self.maximumReadInterval, max(minimumInterval, (ContinuousClock.now - started) * Self.readCostMultiple))
    }

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
