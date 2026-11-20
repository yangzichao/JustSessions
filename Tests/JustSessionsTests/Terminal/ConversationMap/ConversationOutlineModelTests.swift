import Foundation
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct ConversationOutlineModelTests {
    static func model(minimumReadInterval: Duration = .milliseconds(40)) -> ConversationOutlineModel {
        ConversationOutlineModel(checkInterval: .milliseconds(20), minimumReadInterval: minimumReadInterval)
    }

    @Test func theCadenceIsTheBudgets() {
        #expect(ConversationOutlineModel.checkInterval(on: .thisMac) == .seconds(1))
        #expect(ConversationOutlineModel.checkInterval(on: .ssh("host")) == .seconds(5))
        #expect(ConversationOutlineModel.minimumReadInterval == .seconds(2))
        #expect(ConversationOutlineModel.maximumReadInterval == .seconds(30))
        #expect(ConversationOutlineModel.readCostMultiple == 4)
    }

    @Test func aWatchReadsOnceThenOnlyAfterAChange() async throws {
        let fixture = try TranscriptPagingFixture(count: 20)
        defer { fixture.remove() }
        let model = Self.model()
        let watch = OutlineWatch(model, fixture.conversation)
        defer { watch.cancel() }
        try await expectEventually { model.outline?.blocks.count == 20 }
        #expect(model.readCount == 1)
        try await Task.sleep(for: .milliseconds(120))
        #expect(model.readCount == 1)
        try fixture.append(Self.record(20))
        try await expectEventually { model.outline?.blocks.count == 21 }
        #expect(model.readCount == 2)
    }

    @Test func readsWaitTheMinimumInterval() async throws {
        let fixture = try TranscriptPagingFixture(count: 20)
        defer { fixture.remove() }
        let minimumReadInterval = Duration.milliseconds(200)
        let model = Self.model(minimumReadInterval: minimumReadInterval)
        let watch = OutlineWatch(model, fixture.conversation)
        defer { watch.cancel() }
        try await expectEventually { model.readCount == 1 }
        let clock = ContinuousClock()
        let start = clock.now
        var record = 20
        while clock.now < start + .seconds(1) || (model.readCount < 2 && clock.now < start + .seconds(120)) {
            try fixture.append(Self.record(record))
            record += 1
            try await Task.sleep(for: .milliseconds(20))
        }
        let intervals = Int((clock.now - start) / minimumReadInterval)
        #expect(model.readCount > 1)
        #expect(model.readCount <= intervals + 2)
    }

    @Test func relinkingStartsAFreshOutline() async throws {
        let first = try TranscriptPagingFixture(count: 10)
        let second = try TranscriptPagingFixture(count: 0)
        defer {
            first.remove()
            second.remove()
        }
        try SampleTranscriptLines.fileContents(SampleTranscriptLines.codex).write(to: second.file)
        let model = Self.model()
        let watchFirst = OutlineWatch(model, first.conversation)
        try await expectEventually { model.outline?.blocks.count == 10 }
        watchFirst.cancel()
        try await expectEventually { watchFirst.hasEnded }
        let watchSecond = OutlineWatch(model, second.conversation)
        defer { watchSecond.cancel() }
        try await expectEventually { model.outline?.blocks.map(\.snippet).contains("Add a test") == true }
        #expect(model.outline?.blocks.contains { $0.snippet.hasPrefix("Message ") } == false)
    }

    @Test func aSecondWatchTakesOverFromTheFirst() async throws {
        let fixture = try TranscriptPagingFixture(count: 10)
        defer { fixture.remove() }
        let model = Self.model()
        let firstWatch = OutlineWatch(model, fixture.conversation)
        try await expectEventually { model.readCount == 1 }
        let secondWatch = OutlineWatch(model, fixture.conversation)
        defer {
            firstWatch.cancel()
            secondWatch.cancel()
        }
        try await expectEventually { firstWatch.hasEnded }
        #expect(!secondWatch.hasEnded)
        try fixture.append(Self.record(10))
        try await expectEventually { model.outline?.blocks.count == 11 }
    }

    @Test func cancellingTheWatchStopsReading() async throws {
        let fixture = try TranscriptPagingFixture(count: 10)
        defer { fixture.remove() }
        let model = Self.model()
        let watch = OutlineWatch(model, fixture.conversation)
        try await expectEventually { model.outline?.blocks.count == 10 }
        #expect(model.readCount == 1)
        watch.cancel()
        try await expectEventually { watch.hasEnded }
        for record in 10..<15 {
            try fixture.append(Self.record(record))
            try await Task.sleep(for: .milliseconds(40))
        }
        #expect(model.readCount == 1)
        #expect(model.outline?.blocks.count == 10)
    }

    @Test func releasingDropsTheOutline() async throws {
        let fixture = try TranscriptPagingFixture(count: 10)
        defer { fixture.remove() }
        let model = Self.model()
        let watch = OutlineWatch(model, fixture.conversation)
        try await expectEventually { model.outline != nil }
        model.release()
        try await expectEventually { watch.hasEnded }
        #expect(model.outline == nil)
        let latest = try await model.latestMessage(of: fixture.conversation)
        #expect(latest?.entry.id == TranscriptPageIdentity.entryID(record: 9, part: 0))
    }

    @Test func aCancelledReadDoesNotDelayTheNext() async throws {
        let fixture = try TranscriptPagingFixture(count: 200_000)
        defer { fixture.remove() }
        let model = Self.model()
        let first = OutlineWatch(model, fixture.conversation)
        try await expectEventually { model.readCount == 1 }
        try await Task.sleep(for: .milliseconds(500))
        try #require(model.outline == nil, "the first read must still be running when it is cancelled")
        first.cancel()
        try await expectEventually { first.hasEnded }
        let second = OutlineWatch(model, fixture.conversation)
        defer { second.cancel() }
        try await expectEventually(timeout: .seconds(1)) { model.readCount == 2 }
    }

    @Test func aReadUnwindingAfterARelinkDoesNotDelayTheNewSession() async throws {
        let large = try TranscriptPagingFixture(count: 200_000)
        let small = try TranscriptPagingFixture(count: 10)
        defer {
            large.remove()
            small.remove()
        }
        let model = Self.model()
        let clock = ContinuousClock()
        let first = OutlineWatch(model, large.conversation)
        try await expectEventually { model.readCount == 1 }
        let firstReadSeenRunning = clock.now
        try await Task.sleep(for: .milliseconds(500))
        try #require(model.outline == nil, "the first read must still be running when the tab relinks")
        let cancelled = clock.now
        first.cancel()
        let second = OutlineWatch(model, small.conversation)
        defer { second.cancel() }
        try await expectEventually { model.outline?.blocks.count == 10 }
        let spacingTheOldReadWouldHaveCaused = (cancelled - firstReadSeenRunning) * ConversationOutlineModel.readCostMultiple
        #expect(clock.now - cancelled < spacingTheOldReadWouldHaveCaused)
    }

    @Test func aRelinkReadsTheNewSessionWhileTheOldReadRuns() async throws {
        let large = try TranscriptPagingFixture(count: 200_000)
        let small = try TranscriptPagingFixture(count: 10)
        defer {
            large.remove()
            small.remove()
        }
        let model = Self.model()
        let first = OutlineWatch(model, large.conversation)
        try await expectEventually { model.readCount == 1 }
        try await Task.sleep(for: .milliseconds(100))
        try #require(model.outline == nil, "the first read must still be running when the tab relinks")
        let second = OutlineWatch(model, small.conversation)
        defer {
            first.cancel()
            second.cancel()
        }
        try await expectEventually { model.outline?.blocks.count == 10 || first.hasEnded }
        try #require(!first.hasEnded, "the first read must still be running when the new session's outline shows")
        #expect(model.outline?.blocks.count == 10)
    }

    @Test func aDiscardedReadDoesNotDelayTheNewSession() async throws {
        let large = try TranscriptPagingFixture(count: 30_000)
        let small = try TranscriptPagingFixture(count: 10)
        defer {
            large.remove()
            small.remove()
        }
        let model = Self.model()
        let first = OutlineWatch(model, large.conversation)
        try await expectEventually { model.readCount == 1 }
        try await Task.sleep(for: .milliseconds(100))
        try #require(model.outline == nil, "the first read must still be running when the new session's watch starts")
        let second = OutlineWatch(model, small.conversation)
        defer {
            first.cancel()
            second.cancel()
        }
        try await expectEventually { first.hasEnded }
        try await expectEventually(timeout: .seconds(1)) { model.outline?.blocks.count == 10 }
    }

    @Test func aBookmarkForTheSessionLeftLeavesTheMapFollowing() async throws {
        let left = try TranscriptPagingFixture(count: 10)
        let shown = try TranscriptPagingFixture(count: 5)
        defer {
            left.remove()
            shown.remove()
        }
        let model = Self.model()
        let watch = OutlineWatch(model, shown.conversation)
        defer { watch.cancel() }
        try await expectEventually { model.outline?.blocks.count == 5 }
        let latest = try await model.latestMessage(of: left.conversation)
        #expect(latest?.entry.id == TranscriptPageIdentity.entryID(record: 9, part: 0))
        #expect(model.outline?.blocks.count == 5)
        try shown.append(Self.record(5))
        try await expectEventually(timeout: .seconds(5)) { model.outline?.blocks.count == 6 }
    }

    @Test func followingPublishesNothingThroughTheStore() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let fixture = try TranscriptPagingFixture(count: 10)
        defer { fixture.remove() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        store.replaceConversations(on: .thisMac, with: [fixture.conversation])
        let changes = StoreChangeCounter(store)
        defer { changes.cancel() }
        let model = Self.model()
        let watch = OutlineWatch(model, fixture.conversation)
        defer { watch.cancel() }
        for record in 10..<16 {
            try fixture.append(Self.record(record))
            try await Task.sleep(for: .milliseconds(50))
        }
        try await expectEventually { model.outline?.blocks.count == 16 }
        #expect(changes.mainActorTurnsWithChanges == 0)
    }

    static func record(_ number: Int) -> Data {
        let lines = String(decoding: TranscriptPagingFixture.data(count: number + 1), as: UTF8.self).split(separator: "\n")
        return Data((lines[number] + "\n").utf8)
    }
}

@MainActor
final class OutlineWatch {
    private(set) var hasEnded = false
    private var task: Task<Void, Never>?

    init(_ model: ConversationOutlineModel, _ conversation: Conversation) {
        task = Task { [weak self] in
            await model.watch(conversation)
            self?.hasEnded = true
        }
    }

    func cancel() { task?.cancel() }
}
