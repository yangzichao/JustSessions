import Darwin
import Foundation
import Testing

@testable import JustSessions

@_silgen_name("proc_reset_footprint_interval")
private func resetProcessFootprintInterval(_: pid_t) -> Int32

@Suite(.serialized)
struct IncrementalMessageSearchMeasurements {
    static let runCount = 3
    static let baselineLimits = SessionMessageTextReader.wholeSessionLimits
    static let queries = ["First Café", "first cafe", "中文", "🧪", "Appended", "bold words", "naïve"]

    @Test(arguments: ["10", "100", "500", "realistic"])
    func codexSearchText(fixture: String) async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        if let picked = ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF_FIXTURES"],
            !picked.split(separator: ",").contains(Substring(fixture))
        {
            return
        }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sessions = try Path.allCases.map { path in
            let file = directory.appendingPathComponent("\(path.rawValue).jsonl")
            try fixture == "realistic" ? RealisticFixture.write(to: file) : SyntheticFixture.write(sizeMiB: Int(fixture)!, to: file)
            return MeasuredSession(path: path, file: file, cacheDirectory: directory.appendingPathComponent("Cache-\(path.rawValue)"))
        }
        let size = try FileManager.default.attributesOfItem(atPath: sessions[0].file.path)[.size] as! Int
        let records = try Data(contentsOf: sessions[0].file).reduce(0) { $0 + ($1 == 10 ? 1 : 0) }
        let scenario = fixture == "realistic" ? "issue 56, realistic Codex log" : "issue 56, \(fixture) MiB synthetic Codex log"
        perfReport(scenario, "file", "\(size) bytes, \(records) records")

        var samples: [Path: [Sample]] = [:]
        for _ in 0..<Self.runCount {
            for session in sessions {
                session.clearCache()
                samples[session.path, default: []].append(try await session.measure())
            }
        }
        try await check(sessions, scenario: scenario)
        report(samples, scenario: scenario, operation: "cold extraction")
        for session in sessions {
            perfReport(scenario, "\(session.path.rawValue): search entries", session.lastText?.text.entries.count ?? 0)
        }

        samples = [:]
        for _ in 0..<Self.runCount {
            for session in sessions { samples[session.path, default: []].append(try await session.measure()) }
        }
        report(samples, scenario: scenario, operation: "unchanged hit")

        samples = [:]
        var appended = 0
        for _ in 0..<Self.runCount {
            appended += 1
            for session in sessions {
                session.clearCache()
                _ = try await session.measure()
                try session.append(fixture: fixture, number: appended)
                samples[session.path, default: []].append(try await session.measure())
            }
            try await check(sessions, scenario: scenario)
        }
        report(samples, scenario: scenario, operation: "first change")

        samples = [:]
        for _ in 0..<Self.runCount {
            appended += 1
            for session in sessions {
                try session.append(fixture: fixture, number: appended)
                samples[session.path, default: []].append(try await session.measure())
            }
            try await check(sessions, scenario: scenario)
        }
        report(samples, scenario: scenario, operation: "steady one-record append")

        samples = [:]
        for _ in 0..<Self.runCount {
            var runs: [Path: [Sample]] = [:]
            for _ in 0..<10 {
                appended += 1
                for session in sessions {
                    try session.append(fixture: fixture, number: appended)
                    runs[session.path, default: []].append(try await session.measure())
                }
                try await check(sessions, scenario: scenario)
            }
            for (path, run) in runs { samples[path, default: []].append(Sample(adding: run)) }
        }
        report(samples, scenario: scenario, operation: "10 consecutive appends")

        samples = [:]
        for run in 0..<Self.runCount {
            appended += 1
            for session in sessions {
                try session.amendFirstMarker(to: run.isMultiple(of: 2) ? "B" : "A")
                try session.append(fixture: fixture, number: appended)
                samples[session.path, default: []].append(try await session.measure())
            }
            try await check(sessions, scenario: scenario)
        }
        report(samples, scenario: scenario, operation: "amendment rebuild")
    }

    private func check(_ sessions: [MeasuredSession], scenario: String) async throws {
        for session in sessions {
            let clean = try await SessionMessageTextReader.read(
                session.conversation,
                limits: session.path == .baseline ? Self.baselineLimits : SessionMessageTextReader.codexWholeSessionLimits
            )
            let saved = try #require(session.lastText)
            #expect(saved.text == clean, "\(scenario), \(session.path.rawValue)")
            #expect(saved.text.entries.map(\.id) == clean.entries.map(\.id))
            let cleanSearchable = SearchableSessionText(clean)
            for query in Self.queries {
                let parsed = try #require(SessionMessageQuery(query))
                #expect(saved.firstMatch(of: parsed) == cleanSearchable.firstMatch(of: parsed), "\(scenario): \(query)")
            }
        }
    }

    private func report(_ samples: [Path: [Sample]], scenario: String, operation: String) {
        for path in Path.allCases {
            let runs = samples[path] ?? []
            func median<Value: Comparable>(_ value: (Sample) -> Value) -> Value { runs.map(value).sorted()[runs.count / 2] }
            let label = "\(operation), \(path.rawValue)"
            perfReport(scenario, "\(label): wall", median(\.wall))
            perfReport(scenario, "\(label): CPU", median(\.cpu))
            perfReport(scenario, "\(label): source bytes read", median(\.sourceBytes))
            perfReport(scenario, "\(label): records decoded", median(\.decodedRecords))
            perfReport(
                scenario, "\(label): peak footprint growth", String(format: "%.1f MiB", Double(median(\.peakFootprintBytes)) / 1_048_576))
            perfReport(scenario, "\(label): cache bytes written", median(\.cacheBytesWritten))
            perfReport(scenario, "\(label): resumed", "\(runs.filter(\.resumed).count) of \(runs.count)")
        }
    }

    enum Path: String, CaseIterable {
        case baseline
        case resumable
    }

    struct Sample {
        var wall: Duration
        var cpu: Duration
        var sourceBytes: UInt64
        var decodedRecords: Int
        var peakFootprintBytes: UInt64
        var cacheBytesWritten: Int
        var resumed: Bool

        init(
            wall: Duration, cpu: Duration, sourceBytes: UInt64, decodedRecords: Int, peakFootprintBytes: UInt64,
            cacheBytesWritten: Int, resumed: Bool
        ) {
            self.wall = wall
            self.cpu = cpu
            self.sourceBytes = sourceBytes
            self.decodedRecords = decodedRecords
            self.peakFootprintBytes = peakFootprintBytes
            self.cacheBytesWritten = cacheBytesWritten
            self.resumed = resumed
        }

        init(adding samples: [Sample]) {
            self.init(
                wall: samples.map(\.wall).reduce(.zero, +), cpu: samples.map(\.cpu).reduce(.zero, +),
                sourceBytes: samples.map(\.sourceBytes).reduce(0, +), decodedRecords: samples.map(\.decodedRecords).reduce(0, +),
                peakFootprintBytes: samples.map(\.peakFootprintBytes).max() ?? 0,
                cacheBytesWritten: samples.map(\.cacheBytesWritten).reduce(0, +), resumed: samples.allSatisfy(\.resumed)
            )
        }
    }

    final class MeasuredSession {
        let path: Path
        let file: URL
        let conversation: Conversation
        let cacheDirectory: URL
        let cache: SessionMessageTextCache
        private(set) var lastText: SearchableSessionText?

        init(path: Path, file: URL, cacheDirectory: URL) {
            self.path = path
            self.file = file
            self.cacheDirectory = cacheDirectory
            conversation = .fixture(provider: .codex, sessionID: "measured", sourceFile: file)
            cache = SessionMessageTextCache(directory: cacheDirectory)
        }

        func clearCache() { try? FileManager.default.removeItem(at: cacheDirectory) }

        func measure() async throws -> Sample {
            _ = resetProcessFootprintInterval(getpid())
            let startFootprint = Self.footprint().current
            let cpuStart = Self.processCPUTime()
            let wallStart = ContinuousClock.now
            let (text, read, wroteCache) = try await path == .baseline ? baselineText() : resumableText()
            let wall = ContinuousClock.now - wallStart
            let cpu = Self.processCPUTime() - cpuStart
            lastText = text
            let peak = Self.footprint().intervalPeak
            return Sample(
                wall: wall, cpu: cpu, sourceBytes: read?.sourceByteCount ?? 0, decodedRecords: read?.decodedRecordCount ?? 0,
                peakFootprintBytes: peak - min(startFootprint, peak), cacheBytesWritten: wroteCache ? savedByteCount() : 0,
                resumed: read?.resumed ?? false
            )
        }

        private func baselineText() async throws -> (SearchableSessionText, SessionMessageTextRead?, Bool) {
            let fingerprint = SessionMessageTextFingerprint(conversation)
            if let saved = BaselineCache.text(at: cacheFile, for: conversation.id, fingerprint: fingerprint) {
                return (SearchableSessionText(saved), nil, false)
            }
            let read = try await SessionMessageTextReader.readInFull(
                conversation, keepsResumeState: false, limits: IncrementalMessageSearchMeasurements.baselineLimits
            )
            BaselineCache.save(read.text, at: cacheFile, for: conversation.id, fingerprint: fingerprint)
            return (SearchableSessionText(read.text), read, true)
        }

        private func resumableText() async throws -> (SearchableSessionText, SessionMessageTextRead?, Bool) {
            let fingerprint = SessionMessageTextFingerprint(conversation)
            let read: SessionMessageTextRead
            switch cache.lookup(for: conversation.id, fingerprint: fingerprint) {
            case .current(let text):
                return (SearchableSessionText(text), nil, false)
            case .changed(let saved):
                read = try await SessionMessageTextReader.readChanged(conversation, resuming: saved)
            case .missing:
                read = try await SessionMessageTextReader.readInFull(
                    conversation, keepsResumeState: false, limits: SessionMessageTextReader.codexWholeSessionLimits
                )
            }
            cache.save(read.text, resumeState: read.resumeState, for: conversation.id, fingerprint: fingerprint)
            return (SearchableSessionText(read.text), read, true)
        }

        private var cacheFile: URL { cacheDirectory.appendingPathComponent("saved.json") }

        private func savedByteCount() -> Int {
            let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        }

        func append(fixture: String, number: Int) throws {
            let line = fixture == "realistic" ? RealisticFixture.appendedLine(number) : SyntheticFixture.appendedLine(number)
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((line + "\n").utf8))
        }

        func amendFirstMarker(to replacement: Character) throws {
            let handle = try FileHandle(forUpdating: file)
            defer { try? handle.close() }
            let head = try handle.read(upToCount: 4_096) ?? Data()
            let marker = try #require(head.range(of: Data("Marker ".utf8)))
            try handle.seek(toOffset: UInt64(marker.upperBound))
            try handle.write(contentsOf: Data(String(replacement).utf8))
        }

        private static func processCPUTime() -> Duration {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            let microseconds =
                Int64(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1_000_000
                + Int64(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec)
            return .microseconds(microseconds)
        }

        private static func footprint() -> (current: UInt64, intervalPeak: UInt64) {
            var info = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0) }
            }
            return result == 0 ? (info.ri_phys_footprint, info.ri_interval_max_phys_footprint) : (0, 0)
        }
    }

    enum BaselineCache {
        private struct SavedText: Codable {
            let version: Int
            let conversationID: String
            let fingerprint: SessionMessageTextFingerprint
            let text: SessionMessageText
        }

        static func text(at file: URL, for conversationID: String, fingerprint: SessionMessageTextFingerprint) -> SessionMessageText? {
            guard let data = try? Data(contentsOf: file),
                let saved = try? JSONDecoder().decode(SavedText.self, from: data),
                saved.version == 1, saved.conversationID == conversationID, saved.fingerprint == fingerprint
            else { return nil }
            return saved.text
        }

        static func save(_ text: SessionMessageText, at file: URL, for conversationID: String, fingerprint: SessionMessageTextFingerprint) {
            let saved = SavedText(version: 1, conversationID: conversationID, fingerprint: fingerprint, text: text)
            guard let data = try? JSONEncoder().encode(saved) else { return }
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
        }
    }

    enum SyntheticFixture {
        static func write(sizeMiB: Int, to file: URL) throws {
            FileManager.default.createFile(atPath: file.path, contents: nil)
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            let first = message("Marker A: First **Café** 中文 🧪") + "\n"
            try handle.write(contentsOf: Data(first.utf8))
            let hidden = event(padding: 3_800) + "\n"
            let group = Data(
                (message("Searchable checkpoint with **bold words**, naïve") + "\n" + String(repeating: hidden, count: 128)).utf8)
            let target = UInt64(sizeMiB) << 20
            var written = UInt64(first.utf8.count)
            while written < target {
                try handle.write(contentsOf: group)
                written += UInt64(group.count)
            }
        }

        static func appendedLine(_ number: Int) -> String {
            number.isMultiple(of: 2) ? event(padding: 3_800) : message("Appended \(number) Café 中文 🧪")
        }

        static func message(_ text: String) -> String {
            #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"\#(text)"}]}}"#
        }

        static func event(padding: Int) -> String {
            #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"event_msg","payload":{"type":"token_count","padding":"\#(String(repeating: "x", count: padding))"}}"#
        }
    }

    enum RealisticFixture {
        static let targetByteCount = 27 << 20

        static func write(to file: URL) throws {
            FileManager.default.createFile(atPath: file.path, contents: nil)
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            var written = 0
            var turn = 0
            var lines = [SyntheticFixture.message("Marker A: First **Café** 中文 🧪")]
            while written < targetByteCount {
                lines += self.turn(turn)
                let data = Data((lines.joined(separator: "\n") + "\n").utf8)
                try handle.write(contentsOf: data)
                written += data.count
                lines = []
                turn += 1
            }
        }

        static func turn(_ number: Int) -> [String] {
            var lines: [String] = []
            if number.isMultiple(of: 4) { lines.append(user("Turn \(number): please fix the naïve parser, 中文 too")) }
            lines.append(
                SyntheticFixture.message(
                    "Turn \(number): I'll update the parser. Here is the plan with **bold words**:\\n\\n- read the file\\n- change `parse()`\\n\\n"
                        + filler(700)
                ))
            for call in 0..<3 {
                lines.append(toolCall("*** Begin Patch\\n*** Update File: Sources/File\(number)-\(call).swift\\n" + filler(1_050)))
                lines.append(hidden(recordType: "response_item", payloadType: "custom_tool_call_output", padding: 5_000))
                lines.append(hidden(recordType: "event_msg", payloadType: "item_completed", padding: 4_700))
                lines.append(hidden(recordType: "event_msg", payloadType: "token_count", padding: 700))
            }
            lines.append(hidden(recordType: "token_usage_record", payloadType: "usage", padding: 800))
            lines.append(hidden(recordType: "response_item", payloadType: "reasoning", padding: 2_300))
            return lines
        }

        static func appendedLine(_ number: Int) -> String {
            switch number % 5 {
            case 0: SyntheticFixture.message("Appended \(number) Café 中文 🧪")
            case 1: toolCall("*** Begin Patch\\n*** Update File: Sources/Appended\(number).swift\\n" + filler(1_050))
            case 2: hidden(recordType: "response_item", payloadType: "custom_tool_call_output", padding: 5_000)
            case 3: hidden(recordType: "event_msg", payloadType: "item_completed", padding: 4_700)
            default: hidden(recordType: "event_msg", payloadType: "token_count", padding: 700)
            }
        }

        static func user(_ text: String) -> String {
            #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"\#(text)"}]}}"#
        }

        static func toolCall(_ input: String) -> String {
            #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"custom_tool_call","name":"apply_patch","call_id":"call_1","input":"\#(input)"}}"#
        }

        static func hidden(recordType: String, payloadType: String, padding: Int) -> String {
            #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"\#(recordType)","payload":{"type":"\#(payloadType)","output":"\#(filler(padding))"}}"#
        }

        static func filler(_ count: Int) -> String {
            let words = "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor "
            return String(String(repeating: words, count: count / words.count + 1).prefix(count))
        }
    }
}
