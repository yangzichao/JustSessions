import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Recovery projection and appended-name following at many-tab scale, without opening terminals or starting CLIs.
/// JUSTSESSIONS_PERF=1 swift test -c release --no-parallel --filter TerminalScalingMeasurements
@MainActor
@Suite(.serialized)
struct TerminalScalingMeasurements {
    @Test func recoveryOrderWithManyCrossProjectSplits() {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        let clock = ContinuousClock()
        for count in [25, 50, 100, 250] {
            let tabs: [TerminalTabStrip.Tab] = (0..<count).map { .init(id: UUID(), projectKey: "p\($0 / max(count / 10, 1))") }
            var strip = TerminalTabStrip(tabs: tabs)
            for index in 0..<count / 2 {
                _ = strip.addSplit(joining: tabs[index].id, beside: tabs[index + count / 2].id, on: .right)
            }
            var previous: [Duration] = [], projected: [Duration] = []
            for _ in 0..<7 {
                let before = clock.now
                var separated = strip
                separated.separateAllSplits()
                previous.append(clock.now - before)
                let start = clock.now
                let result = strip.tabsWithSplitsSeparated
                projected.append(clock.now - start)
                #expect(result == separated.tabs)
            }
            let label = "recovery, \(count) tabs, \(strip.splits.count) cross-project splits"
            perfReport(label, "separate every split p50", previous.sorted()[3])
            perfReport(label, "direct projection p50", projected.sorted()[3])
        }
    }

    /// Both paths read the same append through the production reader and name extractor. This isolates the work
    /// moved off main; it excludes the store's snapshots and applying actual name changes to the sidebar.
    @Test func appendedPiNamesWhileTheMainActorRemainsAvailable() async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let line = Data(("{\"type\":\"message\",\"message\":{\"role\":\"assistant\",\"content\":\"" + String(repeating: "x", count: 1_968) + "\"}}\n").utf8)
        var append = Data()
        while append.count < Int(AppendedJSONLinesReader.maximumCatchUpByteCount) { append.append(line) }
        append.append(Data("{\"type\":\"session_info\",\"name\":\"performance-name\"}\n".utf8))
        for count in [20, 50, 100] {
            let files = (0..<count).map { folder.appendingPathComponent("\(count)-\($0).jsonl") }
            for file in files { try Data("{}\n".utf8).write(to: file) }
            let lookups = files.enumerated().map { index, file in
                AppendedSessionNameReaders.Lookup(
                    tabID: UUID(), conversation: .fixture(provider: .pi, sessionID: "p\(index)", sourceFile: file), file: file
                )
            }
            var previousReaders = files.map { AppendedJSONLinesReader(file: $0) }
            for index in previousReaders.indices { _ = previousReaders[index].newLines() }
            let reader = AppendedSessionNameReaders()
            _ = await Task.detached(priority: .utility) { await reader.names(for: lookups) }.value
            var oldCPU: [Double] = [], newCPU: [Double] = []
            var oldGaps: [Duration] = [], newGaps: [Duration] = []

            func previousPass() {
                let heartbeat = MainThreadPerfHeartbeat()
                heartbeat.start()
                let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
                var names = 0
                for index in previousReaders.indices {
                    if AppendedSessionNameSource.latestName(for: lookups[index].conversation, amongLines: previousReaders[index].newLines()) != nil {
                        names += 1
                    }
                }
                oldCPU.append(Double(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - start) / 1e6)
                heartbeat.stop()
                oldGaps.append(heartbeat.longestGap)
                #expect(names == count)
            }
            func actorPass() async {
                let heartbeat = MainThreadPerfHeartbeat()
                heartbeat.start()
                let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
                let names = await Task.detached(priority: .utility) { await reader.names(for: lookups) }.value
                newCPU.append(Double(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - start) / 1e6)
                heartbeat.stop()
                newGaps.append(heartbeat.longestGap)
                #expect(names.count == count)
            }
            for round in 0..<7 {
                for file in files {
                    let handle = try FileHandle(forWritingTo: file)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: append)
                    try handle.close()
                }
                if round.isMultiple(of: 2) { previousPass(); await actorPass() }
                else { await actorPass(); previousPass() }
            }
            let label = "appended Pi names, \(count) files, \(append.count) bytes each"
            perfReport(label, "main-thread CPU before / after p50, ms", "\(oldCPU.sorted()[3]) / \(newCPU.sorted()[3])")
            perfReport(label, "longest main-thread gap before p50", oldGaps.sorted()[3])
            perfReport(label, "longest main-thread gap after p50", newGaps.sorted()[3])
        }
    }
}
