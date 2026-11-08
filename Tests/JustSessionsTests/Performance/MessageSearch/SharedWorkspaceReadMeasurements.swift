import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Service-level proxy for 1, 2, and 4 simultaneously searching workspace windows. "isolated" models the former
/// per-window indexes; "shared" uses one `SessionMessageIndexer`. Run with:
///     JUSTSESSIONS_PERF=1 swift test -c release --filter SharedWorkspaceReadMeasurements
@MainActor
@Suite(.serialized)
struct SharedWorkspaceReadMeasurements {
    static let sessionCount = 8
    static let repetitionCount = 3

    /// Query/progress reruns carry unchanged lists; use a distinct array to include element equality in the cost.
    @Test(arguments: [1_000, 10_000])
    func unchangedSearchInputs(sessionCount: Int) async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversations = (0..<sessionCount).map { number in
            Conversation.fixture(provider: .codex, sessionID: "unchanged-\(number)",
                                 updatedAt: Date(timeIntervalSince1970: Double(number)),
                                 sourceFile: directory.appendingPathComponent("\(number).jsonl"))
        }
        let index = SessionMessageIndex(cache: SessionMessageTextCache(directory: directory.appendingPathComponent("Cache")))
        let indexer = SessionMessageIndexer(index: index) { _, _, _ in
            SearchableSessionText(SessionMessageText(entries: []))
        }
        let user = UUID()
        defer { indexer.endUse(by: user) }
        indexer.beginUse(by: user)
        await indexer.update(with: conversations, for: user)
        try await expectEventually(timeout: .seconds(120)) { indexer.revision > 0 && indexer.progress == nil }
        let equalCopy = conversations.map { $0 }
        var times: [Duration] = []
        var baselineTimes: [Duration] = []
        var baselineInputs = [user: conversations]
        let baselineDesired = Self.previousSearchUnion(baselineInputs)
        for _ in 0..<100 {
            let baselineStart = Self.processCPUTime()
            baselineInputs[user] = equalCopy
            let unchanged = Self.previousSearchUnion(baselineInputs) == baselineDesired
            baselineTimes.append(Self.processCPUTime() - baselineStart)
            #expect(unchanged)
            let start = Self.processCPUTime()
            await indexer.update(with: equalCopy, for: user)
            times.append(Self.processCPUTime() - start)
        }
        times.sort()
        baselineTimes.sort()
        let scenario = "unchanged search inputs, \(sessionCount) sessions"
        perfReport(scenario, "CPU p50", times[50])
        perfReport(scenario, "CPU p95", times[95])
        perfReport(scenario, "previous union/sort CPU p50", baselineTimes[50])
        perfReport(scenario, "previous union/sort CPU p95", baselineTimes[95])
        #expect(await index.sessionCount() == sessionCount)
    }

    /// The pre-fix unchanged-input bookkeeping, on exactly the same Conversation values as the current path.
    private static func previousSearchUnion(_ inputs: [UUID: [Conversation]]) -> [Conversation] {
        var byID: [String: Conversation] = [:]
        for conversations in inputs.values {
            for conversation in conversations {
                if let found = byID[conversation.id], found.updatedAt > conversation.updatedAt { continue }
                byID[conversation.id] = conversation
            }
        }
        return byID.values.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id < $1.id
        }
    }

    @Test func simultaneousSearchIndexing() async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        for windowCount in [1, 2, 4] {
            for repetition in 1...Self.repetitionCount {
                try await measure(windowCount: windowCount, shared: false, repetition: repetition)
                try await measure(windowCount: windowCount, shared: true, repetition: repetition)
            }
        }
    }

    @Test func simultaneousFullDiscovery() async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        for windowCount in [1, 2, 4] {
            for repetition in 1...Self.repetitionCount {
                try await measureDiscovery(windowCount: windowCount, shared: false, repetition: repetition)
                try await measureDiscovery(windowCount: windowCount, shared: true, repetition: repetition)
            }
        }
    }

    private func measure(windowCount: Int, shared: Bool, repetition: Int) async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversations = try (0..<Self.sessionCount).map { number in
            let id = "measurement-\(number)"
            let file = directory.appendingPathComponent("\(id).jsonl")
            let payload = String(repeating: "searchable-\(number)-", count: 2_000)
            let line = #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"\#(payload)"}]}}"#
            try SampleTranscriptLines.fileContents([line]).write(to: file)
            return Conversation.fixture(provider: .codex, sessionID: id, sourceFile: file)
        }
        let sourceBytesPerIndex = conversations.reduce(0) {
            $0 + ((try? $1.sourceFile.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        let counters = WorkspaceReadMeasurementCounters()
        let makeIndexer = { (cacheNumber: Int) -> SessionMessageIndexer in
            let cache = SessionMessageTextCache(directory: directory.appendingPathComponent("Cache-\(cacheNumber)"))
            return SessionMessageIndexer(index: SessionMessageIndex(cache: cache)) { conversation, fingerprint, cache in
                let bytes = (try? conversation.sourceFile.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                await counters.recordSourceRead(bytes: bytes)
                return await SessionMessageIndex.searchableText(of: conversation, fingerprint: fingerprint, cache: cache)
            }
        }
        let indexers = shared ? [makeIndexer(0)] : (0..<windowCount).map(makeIndexer)
        let users = (0..<windowCount).map { _ in UUID() }
        let cpuStart = Self.processCPUTime()
        let wallStart = ContinuousClock.now
        for (window, user) in users.enumerated() {
            let indexer = shared ? indexers[0] : indexers[window]
            indexer.beginUse(by: user)
            await indexer.update(with: conversations, for: user)
        }
        for indexer in indexers {
            try await expectEventually(timeout: .seconds(120)) { indexer.revision > 0 && indexer.progress == nil }
        }
        let wall = ContinuousClock.now - wallStart
        let cpu = Self.processCPUTime() - cpuStart
        let firstCounts = await counters.snapshot()

        // Repeating the same simultaneous search generation must do no further source or cache reads.
        for (window, user) in users.enumerated() {
            let indexer = shared ? indexers[0] : indexers[window]
            await indexer.update(with: conversations, for: user)
        }
        let repeatedCounts = await counters.snapshot()
        var entries = 0
        for indexer in indexers { entries += await indexer.index.sessionCount() }

        let mode = shared ? "shared" : "isolated"
        let scenario = "workspace message search, \(windowCount) window(s), \(mode), run \(repetition)"
        perfReport(scenario, "wall time", wall)
        perfReport(scenario, "CPU time", cpu)
        perfReport(scenario, "adapter scans", "not exercised")
        perfReport(scenario, "source reads", firstCounts.reads)
        perfReport(scenario, "source bytes read", firstCounts.bytes)
        perfReport(scenario, "cache bytes read", 0)
        perfReport(scenario, "index entries", entries)
        perfReport(scenario, "folded-text copies", firstCounts.reads)
        perfReport(scenario, "extra reads for repeated generation", repeatedCounts.reads - firstCounts.reads)
        perfReport(scenario, "expected source bytes for one index", sourceBytesPerIndex)
        perfReport(scenario, "subprocess probes", "not exercised")
        perfReport(scenario, "process peak RSS", Self.peakResidentBytes())
    }

    private func measureDiscovery(windowCount: Int, shared: Bool, repetition: Int) async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = directory.appendingPathComponent("probes.txt")
        let adapter = DiscoveryMeasurementAdapter()
        let serviceCount = shared ? 1 : windowCount
        let services = try (0..<serviceCount).map { number in
            let bin = directory.appendingPathComponent("bin-\(number)")
            try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
            let tmux = bin.appendingPathComponent("tmux")
            let script = """
                #!/bin/sh
                echo probe >> '\(log.path)'
                if [ "$1" = "-V" ]; then echo 'tmux 3.5'; exit 0; fi
                exit 1
                """
            try script.write(to: tmux, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmux.path)
            let resolver = NativeCLICommandResolver(
                searchDirectories: [bin.path], inheritedEnvironment: [:], bundledTmuxDirectory: nil
            )
            return WorkspaceReadService(adapters: [adapter], commandResolver: resolver)
        }
        let stores = (0..<windowCount).map { number in
            ConversationStore(startsBackgroundPolling: false, readService: services[shared ? 0 : number])
        }
        let expectedScans = serviceCount
        if shared {
            stores[0].refreshThisMac()
            try await expectEventually { adapter.discoveryCount == 1 }
            for store in stores.dropFirst() { store.refreshThisMac() }
        } else {
            for store in stores { store.refreshThisMac() }
            try await expectEventually { adapter.discoveryCount == expectedScans }
        }
        adapter.allowDiscoveriesToFinish(count: expectedScans)
        try await expectEventually(timeout: .seconds(120)) { stores.allSatisfy { !$0.isScanningThisMac } }

        let probes = (try? String(contentsOf: log, encoding: .utf8).split(whereSeparator: \.isNewline).count) ?? 0
        let mode = shared ? "shared" : "isolated"
        let scenario = "workspace full discovery, \(windowCount) window(s), \(mode), run \(repetition)"
        perfReport(scenario, "adapter scans", adapter.discoveryCount)
        perfReport(scenario, "subprocess probes", probes)
    }

    private static func processCPUTime() -> Duration {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let microseconds = Int64(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1_000_000
            + Int64(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec)
        return .microseconds(microseconds)
    }

    private static func peakResidentBytes() -> Int64 {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Int64(usage.ru_maxrss)
    }
}

private final class DiscoveryMeasurementAdapter: ConversationAdapter, @unchecked Sendable {
    let provider = ConversationProvider.claude
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var count = 0

    var discoveryCount: Int { lock.withLock { count } }

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        lock.withLock { count += 1 }
        while !cancellation.isCancelled,
              gate.wait(timeout: .now() + .milliseconds(10)) == .timedOut {}
        try cancellation.checkCancellation()
        return []
    }

    func allowDiscoveriesToFinish(count: Int) {
        for _ in 0..<count { gate.signal() }
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }
    func delete(_ conversation: Conversation) throws {}
}

private actor WorkspaceReadMeasurementCounters {
    private var reads = 0
    private var bytes = 0

    func recordSourceRead(bytes: Int) {
        reads += 1
        self.bytes += bytes
    }

    func snapshot() -> (reads: Int, bytes: Int) { (reads, bytes) }
}
